require "swagger_helper"

RSpec.describe "Job postings API", type: :request do
  let(:user) { create(:user) }

  before { sign_in(user) }

  path "/api/v1/job_postings" do
    get "List, filter and search your job postings" do
      tags "Job postings"
      produces "application/json"
      security [ { session_cookie: [] } ]
      parameter name: :status, in: :query, type: :string, required: false,
        description: "Comma-separated statuses, e.g. applied,interviewing"
      parameter name: :q, in: :query, type: :string, required: false, description: "Words to find in title, company or location"
      parameter name: :deadline, in: :query, required: false, schema: { type: :string, enum: JobPostingsQuery::DEADLINES },
        description: "upcoming = within #{JobPostingsQuery::UPCOMING_DAYS} days"
      parameter name: :sort, in: :query, required: false, schema: { type: :string, enum: JobPostingsQuery::SORTS.keys, default: "newest" }
      parameter name: :page, in: :query, type: :integer, required: false
      parameter name: :per_page, in: :query, required: false,
        schema: { type: :integer, default: JobPostingsQuery::DEFAULT_PER_PAGE, maximum: JobPostingsQuery::MAX_PER_PAGE }

      response "200", "postings (without the full description) and paging info" do
        schema type: :object, required: %w[job_postings meta],
          properties: {
            job_postings: { type: :array, items: { "$ref" => "#/components/schemas/JobPostingSummary" } },
            meta: {
              type: :object, required: %w[page per_page total total_pages],
              properties: { page: { type: :integer }, per_page: { type: :integer }, total: { type: :integer }, total_pages: { type: :integer } }
            }
          }

        before do
          create(:job_posting, user:, title: "Older", created_at: 2.days.ago)
          create(:job_posting, user:, title: "Newer")
          create(:job_posting, title: "Someone else's")
        end

        run_test! do
          expect(json["job_postings"].pluck("title")).to eq(%w[Newer Older])
          expect(json["job_postings"].first).not_to have_key("description")
          expect(json["meta"]).to eq("page" => 1, "per_page" => 20, "total" => 2, "total_pages" => 1)
        end
      end

      response "200", "filtered" do
        let(:q) { "lead" }
        let(:per_page) { 1 }

        before do
          create(:job_posting, user:, title: "Lead Rails Developer")
          create(:job_posting, user:, title: "Lead Engineer")
          create(:job_posting, user:, title: "Junior Developer")
        end

        run_test! do
          expect(json["job_postings"].size).to eq(1)
          expect(json["meta"]).to include("total" => 2, "total_pages" => 2)
        end
      end
    end

    post "Add a job posting from pasted text" do
      tags "Job postings"
      consumes "application/json"
      produces "application/json"
      security [ { session_cookie: [], csrf_token: [] } ]
      parameter name: :body, in: :body, schema: {
        type: :object, required: %w[job_posting],
        properties: { job_posting: { "$ref" => "#/components/schemas/JobPostingInput" } }
      }

      response "201", "created" do
        schema "$ref" => "#/components/schemas/JobPostingEnvelope"
        let(:body) do
          { job_posting: { title: "Rails Developer", company: "Acme", work_model: "remote",
                           deadline: "2026-11-30", description: "Build APIs with Rails." } }
        end

        run_test! do
          expect(user.job_postings.sole).to have_attributes(title: "Rails Developer", deadline: Date.new(2026, 11, 30))
        end
      end

      response "422", "invalid" do
        schema "$ref" => "#/components/schemas/Problem"
        let(:body) { { job_posting: { title: "", company: "Acme", description: "", work_model: "on the moon" } } }

        run_test! do
          expect(json["errors"].keys).to contain_exactly("title", "description", "work_model")
        end
      end
    end
  end

  path "/api/v1/job_postings/{id}" do
    parameter name: :id, in: :path, type: :integer

    get "Show a job posting with its full text" do
      tags "Job postings"
      produces "application/json"
      security [ { session_cookie: [] } ]

      response "200", "posting" do
        schema "$ref" => "#/components/schemas/JobPostingEnvelope"
        let(:id) { create(:job_posting, user:).id }

        run_test! do
          expect(json["job_posting"]["description"]).to include("Rails developer")
        end
      end

      response "404", "not one of your postings" do
        schema "$ref" => "#/components/schemas/Problem"
        let(:id) { create(:job_posting).id }
        run_test!
      end
    end

    patch "Update a job posting" do
      tags "Job postings"
      consumes "application/json"
      produces "application/json"
      security [ { session_cookie: [], csrf_token: [] } ]
      description "Send only the fields to change."
      parameter name: :body, in: :body, schema: {
        type: :object, required: %w[job_posting],
        properties: { job_posting: { "$ref" => "#/components/schemas/JobPostingInput" } }
      }

      let(:posting) { create(:job_posting, user:) }
      let(:id) { posting.id }

      response "200", "updated" do
        schema "$ref" => "#/components/schemas/JobPostingEnvelope"
        let(:body) { { job_posting: { title: "Lead Rails Developer", deadline: nil } } }

        run_test! do
          expect(posting.reload).to have_attributes(title: "Lead Rails Developer", deadline: nil, company: "Acme Oy")
        end
      end

      response "422", "invalid" do
        schema "$ref" => "#/components/schemas/Problem"
        let(:body) { { job_posting: { company: "" } } }
        run_test!
      end

      response "404", "not one of your postings" do
        schema "$ref" => "#/components/schemas/Problem"
        let(:id) { create(:job_posting).id }
        let(:body) { { job_posting: { title: "Hijacked" } } }

        run_test! do
          expect(JobPosting.find(id).title).not_to eq("Hijacked")
        end
      end
    end

    delete "Delete a job posting" do
      tags "Job postings"
      security [ { session_cookie: [], csrf_token: [] } ]

      response "204", "deleted" do
        let(:id) { create(:job_posting, user:).id }

        run_test! do
          expect(JobPosting.exists?(id)).to be(false)
        end
      end

      response "404", "not one of your postings" do
        schema "$ref" => "#/components/schemas/Problem"
        let(:id) { create(:job_posting).id }

        run_test! do
          expect(JobPosting.exists?(id)).to be(true)
        end
      end
    end
  end

  it "requires signing in" do
    delete "/api/v1/session"
    get "/api/v1/job_postings"
    expect(response).to have_http_status(:unauthorized)
  end
end
