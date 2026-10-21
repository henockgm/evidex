require "swagger_helper"

RSpec.describe "Job applications API", type: :request do
  let(:user) { create(:user) }
  let(:posting) { create(:job_posting, user:) }

  before { sign_in(user) }

  path "/api/v1/job_applications/{id}" do
    parameter name: :id, in: :path, type: :integer

    patch "Update application details" do
      tags "Applications"
      consumes "application/json"
      produces "application/json"
      security [ { session_cookie: [], csrf_token: [] } ]
      description "Send only the fields to change. `links` replaces the whole list; send [] to clear it."
      parameter name: :body, in: :body, schema: {
        type: :object, required: %w[job_application],
        properties: { job_application: { "$ref" => "#/components/schemas/JobApplicationInput" } }
      }

      let(:id) { posting.job_application.id }

      response "200", "updated" do
        schema type: :object, required: %w[application], properties: { application: { "$ref" => "#/components/schemas/JobApplication" } }
        let(:body) do
          { job_application: { applied_on: "2026-10-18", next_action: "Follow up with the recruiter", next_action_on: "2026-10-25",
                               notes: "Referred by Ana.", links: [ { label: "Portal", url: "https://jobs.example.com/status/1" } ] } }
        end

        run_test! do
          expect(posting.job_application.reload).to have_attributes(
            applied_on: Date.new(2026, 10, 18), next_action: "Follow up with the recruiter",
            next_action_on: Date.new(2026, 10, 25), notes: "Referred by Ana.",
            links: [ { "label" => "Portal", "url" => "https://jobs.example.com/status/1" } ]
          )
          expect(json["application"]["next_action"]).to eq("Follow up with the recruiter")
        end
      end

      response "422", "invalid" do
        schema "$ref" => "#/components/schemas/Problem"
        let(:body) { { job_application: { links: [ { label: "x", url: "ftp://example.com" } ] } } }
        run_test!
      end

      response "404", "someone else's application" do
        schema "$ref" => "#/components/schemas/Problem"
        let(:id) { create(:job_posting).job_application.id }
        let(:body) { { job_application: { notes: "Hijacked" } } }

        run_test! do
          expect(JobApplication.find(id).notes).to be_nil
        end
      end
    end
  end

  it "clears links with an empty list and ignores the status field" do
    application = posting.job_application
    application.update!(links: [ { url: "https://example.com" } ])

    patch "/api/v1/job_applications/#{application.id}", params: { job_application: { links: [], status: "offer" } }, as: :json

    expect(response).to have_http_status(:ok)
    expect(application.reload).to have_attributes(links: [], status: "saved")
  end

  path "/api/v1/job_applications/{id}/transitions" do
    parameter name: :id, in: :path, type: :integer

    post "Move an application to a new status" do
      tags "Applications"
      consumes "application/json"
      produces "application/json"
      security [ { session_cookie: [], csrf_token: [] } ]
      description "Allowed next statuses are listed in the application's available_transitions."
      parameter name: :body, in: :body, schema: {
        type: :object, required: %w[to_status],
        properties: {
          to_status: { "$ref" => "#/components/schemas/ApplicationStatus" },
          note: { type: :string, maxLength: JobApplication::NOTE_MAX_LENGTH, description: "Optional, shown in the timeline" }
        }
      }

      let(:id) { posting.job_application.id }

      response "200", "moved; returns the application with its timeline" do
        schema type: :object, required: %w[application], properties: { application: { "$ref" => "#/components/schemas/JobApplication" } }
        let(:body) { { to_status: "applied", note: "Applied through their careers page" } }

        run_test! do
          expect(json["application"]).to include("status" => "applied", "available_transitions" => %w[interviewing offer rejected no_response withdrawn])
          expect(json["application"]["events"].last).to include("from_status" => "saved", "to_status" => "applied",
            "note" => "Applied through their careers page")
        end
      end

      response "422", "not allowed from the current status" do
        schema "$ref" => "#/components/schemas/Problem"
        let(:body) { { to_status: "offer" } }

        run_test! do
          expect(json["detail"]).to eq("Can't move from saved to offer")
          expect(posting.job_application.reload.status).to eq("saved")
        end
      end

      response "404", "someone else's application" do
        schema "$ref" => "#/components/schemas/Problem"
        let(:id) { create(:job_posting).job_application.id }
        let(:body) { { to_status: "withdrawn" } }

        run_test! do
          expect(JobApplication.find(id).status).to eq("saved")
        end
      end
    end
  end

  it "rejects notes over the length limit without changing the status" do
    post "/api/v1/job_applications/#{posting.job_application.id}/transitions",
      params: { to_status: "applied", note: "x" * (JobApplication::NOTE_MAX_LENGTH + 1) }, as: :json

    expect(response).to have_http_status(:unprocessable_content)
    expect(json["errors"]).to have_key("note")
    expect(posting.job_application.reload.status).to eq("saved")
  end

  it "shows each posting's status in the list and the full application on the posting" do
    posting.job_application.transition_to!("preparing")

    get "/api/v1/job_postings"
    expect(json["job_postings"].sole["status"]).to eq("preparing")

    get "/api/v1/job_postings/#{posting.id}"
    expect(json["job_posting"]["application"]).to include("status" => "preparing", "available_transitions" => %w[saved applied withdrawn])
    expect(json["job_posting"]["application"]["events"].pluck("to_status")).to eq(%w[saved preparing])
  end
end
