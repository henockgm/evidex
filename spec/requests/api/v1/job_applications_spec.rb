require "swagger_helper"

RSpec.describe "Job applications API", type: :request do
  let(:user) { create(:user) }
  let(:posting) { create(:job_posting, user:) }

  before { sign_in(user) }

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
          expect(json["application"]).to include("status" => "applied", "available_transitions" => %w[interviewing offer rejected withdrawn])
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
