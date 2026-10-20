require "swagger_helper"

RSpec.describe "Requirements API", type: :request do
  let(:user) { create(:user) }
  let(:posting) { create(:job_posting, user:) }

  before { sign_in(user) }

  path "/api/v1/job_postings/{job_posting_id}/requirements" do
    parameter name: :job_posting_id, in: :path, type: :integer

    post "Add a requirement to a posting" do
      tags "Job postings"
      consumes "application/json"
      produces "application/json"
      security [ { session_cookie: [], csrf_token: [] } ]
      parameter name: :body, in: :body, schema: {
        type: :object, required: %w[requirement],
        properties: { requirement: { type: :object, required: %w[kind text], properties: {
          kind: { type: :string, enum: Requirement::KINDS },
          text: { type: :string, maxLength: Requirement::TEXT_MAX_LENGTH }
        } } }
      }

      let(:job_posting_id) { posting.id }

      response "201", "added at the end of its kind" do
        schema type: :object, required: %w[requirement], properties: { requirement: { "$ref" => "#/components/schemas/Requirement" } }
        let(:body) { { requirement: { kind: "preferred", text: "  Experience with   pgvector " } } }

        run_test! do
          expect(posting.requirements.sole).to have_attributes(kind: "preferred", text: "Experience with pgvector", position: 1)
        end
      end

      response "422", "invalid" do
        schema "$ref" => "#/components/schemas/Problem"
        let(:body) { { requirement: { kind: "nice to have", text: "" } } }

        run_test! do
          expect(json["errors"].keys).to contain_exactly("kind", "text")
        end
      end

      response "404", "not one of your postings" do
        schema "$ref" => "#/components/schemas/Problem"
        let(:job_posting_id) { create(:job_posting).id }
        let(:body) { { requirement: { kind: "required", text: "Planted" } } }

        run_test! do
          expect(Requirement.count).to eq(0)
        end
      end
    end
  end

  path "/api/v1/requirements/{id}" do
    parameter name: :id, in: :path, type: :integer

    patch "Change a requirement's text" do
      tags "Job postings"
      consumes "application/json"
      produces "application/json"
      security [ { session_cookie: [], csrf_token: [] } ]
      parameter name: :body, in: :body, schema: {
        type: :object, required: %w[requirement],
        properties: { requirement: { type: :object, required: %w[text], properties: { text: { type: :string } } } }
      }

      let(:requirement) { create(:requirement, job_posting: posting, text: "Ruby") }
      let(:id) { requirement.id }

      response "200", "updated" do
        schema type: :object, required: %w[requirement], properties: { requirement: { "$ref" => "#/components/schemas/Requirement" } }
        let(:body) { { requirement: { text: "Ruby on Rails, 3+ years" } } }

        run_test! do
          expect(requirement.reload.text).to eq("Ruby on Rails, 3+ years")
        end
      end

      response "404", "someone else's requirement" do
        schema "$ref" => "#/components/schemas/Problem"
        let(:id) { create(:requirement).id }
        let(:body) { { requirement: { text: "Changed" } } }

        run_test! do
          expect(Requirement.find(id).text).not_to eq("Changed")
        end
      end
    end

    delete "Remove a requirement" do
      tags "Job postings"
      security [ { session_cookie: [], csrf_token: [] } ]

      response "204", "removed" do
        let(:id) { create(:requirement, job_posting: posting).id }

        run_test! do
          expect(Requirement.exists?(id)).to be(false)
        end
      end

      response "404", "someone else's requirement" do
        schema "$ref" => "#/components/schemas/Problem"
        let(:id) { create(:requirement).id }
        run_test!
      end
    end
  end

  it "includes the requirements, each kind in the order added, in the posting" do
    create(:requirement, job_posting: posting, kind: "required", text: "Rails")
    create(:requirement, job_posting: posting, kind: "responsibility", text: "Build APIs")
    create(:requirement, job_posting: posting, kind: "required", text: "PostgreSQL")

    get "/api/v1/job_postings/#{posting.id}"

    by_kind = json["job_posting"]["requirements"].group_by { |r| r["kind"] }.transform_values { |rs| rs.pluck("text") }
    expect(by_kind).to eq("required" => %w[Rails PostgreSQL], "responsibility" => [ "Build APIs" ])
  end
end
