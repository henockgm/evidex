require "swagger_helper"

RSpec.describe "Interviews API", type: :request do
  let(:user) { create(:user) }
  let(:application) { create(:job_posting, user:).job_application }

  before { sign_in(user) }

  interview_input = {
    type: :object,
    properties: {
      round: { type: :string, nullable: true, maxLength: 100 },
      scheduled_at: { type: :string, format: "date-time", description: "ISO 8601 with a time zone offset" },
      format: { type: :string, enum: Interview::FORMATS, nullable: true },
      location: { type: :string, nullable: true, maxLength: 500, description: "Address or meeting link" },
      status: { type: :string, enum: Interview::STATUSES },
      notes: { type: :string, nullable: true }
    }
  }

  path "/api/v1/job_applications/{job_application_id}/interviews" do
    parameter name: :job_application_id, in: :path, type: :integer

    post "Add an interview" do
      tags "Applications"
      consumes "application/json"
      produces "application/json"
      security [ { session_cookie: [], csrf_token: [] } ]
      description "Also moves the application to interviewing when that is an allowed next status."
      parameter name: :body, in: :body, schema: {
        type: :object, required: %w[interview], properties: { interview: interview_input.merge(required: %w[scheduled_at]) }
      }

      let(:job_application_id) { application.id }

      response "201", "added" do
        schema type: :object, required: %w[interview], properties: { interview: { "$ref" => "#/components/schemas/Interview" } }
        let(:body) { { interview: { round: "1st round", scheduled_at: "2026-10-28T14:00:00+03:00", format: "video", location: "https://meet.example.com/abc" } } }

        before { application.transition_to!("applied") }

        run_test! do
          expect(application.interviews.sole).to have_attributes(round: "1st round", format: "video", status: "scheduled",
            scheduled_at: Time.zone.parse("2026-10-28T11:00:00Z"))
          expect(application.reload.status).to eq("interviewing")
          expect(application.events.last.note).to eq("Interview scheduled: 1st round")
        end
      end

      response "422", "invalid" do
        schema "$ref" => "#/components/schemas/Problem"
        let(:body) { { interview: { scheduled_at: "", format: "carrier pigeon" } } }

        run_test! do
          expect(json["errors"].keys).to contain_exactly("scheduled_at", "format")
          expect(application.reload.status).to eq("saved")
        end
      end

      response "404", "someone else's application" do
        schema "$ref" => "#/components/schemas/Problem"
        let(:job_application_id) { create(:job_posting).job_application.id }
        let(:body) { { interview: { scheduled_at: "2026-10-28T14:00:00Z" } } }
        run_test!
      end
    end
  end

  path "/api/v1/interviews/{id}" do
    parameter name: :id, in: :path, type: :integer

    patch "Update an interview (e.g. mark it completed)" do
      tags "Applications"
      consumes "application/json"
      produces "application/json"
      security [ { session_cookie: [], csrf_token: [] } ]
      parameter name: :body, in: :body, schema: { type: :object, required: %w[interview], properties: { interview: interview_input } }

      let(:interview) { create(:interview, job_application: application) }
      let(:id) { interview.id }

      response "200", "updated" do
        schema type: :object, required: %w[interview], properties: { interview: { "$ref" => "#/components/schemas/Interview" } }
        let(:body) { { interview: { status: "completed", notes: "Went well; they'll reply next week." } } }

        run_test! do
          expect(interview.reload).to have_attributes(status: "completed", notes: "Went well; they'll reply next week.")
        end
      end

      response "404", "someone else's interview" do
        schema "$ref" => "#/components/schemas/Problem"
        let(:id) { create(:interview).id }
        let(:body) { { interview: { status: "cancelled" } } }

        run_test! do
          expect(Interview.find(id).status).to eq("scheduled")
        end
      end
    end

    delete "Remove an interview" do
      tags "Applications"
      security [ { session_cookie: [], csrf_token: [] } ]

      response "204", "removed" do
        let(:id) { create(:interview, job_application: application).id }
        run_test!
      end
    end
  end

  it "keeps the status when the application is already past interviewing" do
    application.transition_to!("applied")
    application.transition_to!("offer")

    post "/api/v1/job_applications/#{application.id}/interviews", params: { interview: { scheduled_at: 2.days.from_now.iso8601 } }, as: :json

    expect(response).to have_http_status(:created)
    expect(application.reload.status).to eq("offer")
  end
end
