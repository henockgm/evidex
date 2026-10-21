require "swagger_helper"

RSpec.describe "Dashboard API", type: :request do
  let(:user) { create(:user) }

  before { sign_in(user) }

  brief = { job_posting_id: { type: :integer }, title: { type: :string }, company: { type: :string } }

  path "/api/v1/dashboard" do
    get "Counts per status, upcoming deadlines, next actions and recent activity" do
      tags "Applications"
      produces "application/json"
      security [ { session_cookie: [] } ]

      response "200", "dashboard" do
        schema type: :object,
          required: %w[status_counts total upcoming_interviews upcoming_deadlines next_actions recent_activity],
          properties: {
            status_counts: {
              type: :object, required: JobApplication::STATUSES,
              properties: JobApplication::STATUSES.index_with { { type: :integer } }
            },
            total: { type: :integer },
            upcoming_interviews: {
              type: :array, description: "Scheduled within #{DashboardQuery::INTERVIEW_WINDOW.in_days.to_i} days",
              items: { type: :object, required: %w[job_posting_id title company interview_id round format scheduled_at],
                       properties: brief.merge(interview_id: { type: :integer }, round: { type: :string, nullable: true },
                         format: { type: :string, nullable: true }, scheduled_at: { type: :string, format: "date-time" }) }
            },
            upcoming_deadlines: {
              type: :array, description: "Not applied yet, deadline within #{DashboardQuery::DEADLINE_WINDOW.in_days.to_i} days",
              items: { type: :object, required: %w[job_posting_id title company deadline],
                       properties: brief.merge(deadline: { type: :string, format: :date }) }
            },
            next_actions: {
              type: :array, description: "Due within #{DashboardQuery::NEXT_ACTION_WINDOW.in_days.to_i} days, overdue included",
              items: { type: :object, required: %w[job_posting_id title company next_action next_action_on overdue],
                       properties: brief.merge(next_action: { type: :string, nullable: true },
                         next_action_on: { type: :string, format: :date }, overdue: { type: :boolean }) }
            },
            recent_activity: {
              type: :array,
              items: { type: :object, required: %w[job_posting_id title company to_status created_at],
                       properties: brief.merge(
                         from_status: { allOf: [ { "$ref" => "#/components/schemas/ApplicationStatus" } ], nullable: true },
                         to_status: { "$ref" => "#/components/schemas/ApplicationStatus" },
                         created_at: { type: :string, format: "date-time" }
                       ) }
            }
          }

        before do
          create(:job_posting, user:, deadline: 3.days.from_now.to_date).job_application
            .update!(next_action: "Ask about salary", next_action_on: Date.current)
        end

        run_test! do
          expect(json["total"]).to eq(1)
          expect(json["upcoming_deadlines"].size).to eq(1)
          expect(json["next_actions"].sole).to include("next_action" => "Ask about salary", "overdue" => false)
        end
      end
    end
  end
end
