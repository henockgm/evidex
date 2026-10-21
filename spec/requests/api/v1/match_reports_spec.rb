require "swagger_helper"

RSpec.describe "Match reports API", type: :request do
  let(:user) { create(:user) }
  let(:posting) { create(:job_posting, user:) }

  before { sign_in(user) }

  def prepare_library
    create(:requirement, job_posting: posting, text: "Ruby on Rails")
    create(:document, user:).tap { |document| ProcessDocumentJob.perform_now(document.id) }
  end

  def finished_report
    posting.match_reports.create!(user:, version: 1, status: "done", model: "claude-opus-5-5", completed_at: Time.current,
      strengths: [ "Rails" ], gaps: [ "Kubernetes" ]).tap do |report|
      match = report.matches.create!(requirement_kind: "required", requirement_text: "Ruby on Rails", verdict: "evidenced",
        reasoning: "Built APIs with Rails.", position: 0)
      match.citations.create!(document_title: "My CV", page: 1, section: "Experience", excerpt: "Built REST APIs with Ruby on Rails.")
    end
  end

  path "/api/v1/job_postings/{job_posting_id}/match_reports" do
    parameter name: :job_posting_id, in: :path, type: :integer

    post "Start a match report for a posting" do
      tags "Match reports"
      produces "application/json"
      security [ { session_cookie: [], csrf_token: [] } ]
      description <<~TEXT
        Runs in the background; poll GET /api/v1/job_postings/{id}/match_report until status is "done" or "failed".
        Each run is a new version. Needs a confirmed email, requirements on the posting, at least one processed
        document, and counts toward the daily AI limit.
      TEXT

      let(:job_posting_id) { posting.id }

      response "202", "started", ai: true do
        schema type: :object, required: %w[match_report], properties: { match_report: { "$ref" => "#/components/schemas/MatchReport" } }
        before { prepare_library }

        run_test! do
          expect(json["match_report"]).to include("version" => 1, "status" => "pending")
          expect(GenerateMatchReportJob).to have_been_enqueued
        end
      end

      response "422", "no requirements or empty library", ai: true do
        schema "$ref" => "#/components/schemas/Problem"
        run_test! do
          expect(json["title"]).to eq("No requirements")
        end
      end

      response "409", "a report is already being prepared", ai: true do
        schema "$ref" => "#/components/schemas/Problem"
        before do
          prepare_library
          posting.match_reports.create!(user:, version: 1, status: "running")
        end
        run_test!
      end
    end
  end

  path "/api/v1/job_postings/{id}/match_report" do
    parameter name: :id, in: :path, type: :integer

    get "The latest match report for a posting" do
      tags "Match reports"
      produces "application/json"
      security [ { session_cookie: [] } ]

      response "200", "latest report" do
        schema type: :object, required: %w[match_report], properties: { match_report: { "$ref" => "#/components/schemas/MatchReport" } }
        let(:id) { posting.id }
        before { finished_report }

        run_test! do
          report = json["match_report"]
          expect(report["counts"]).to eq("evidenced" => 1, "transferable" => 0, "gap" => 0)
          expect(report["matches"].first["citations"].first).to include("document_title" => "My CV", "page" => 1)
        end
      end

      response "404", "no report yet" do
        schema "$ref" => "#/components/schemas/Problem"
        let(:id) { posting.id }
        run_test!
      end
    end
  end

  path "/api/v1/match_reports/{id}" do
    parameter name: :id, in: :path, type: :integer

    get "A specific match report version" do
      tags "Match reports"
      produces "application/json"
      security [ { session_cookie: [] } ]

      response "200", "report" do
        schema type: :object, required: %w[match_report], properties: { match_report: { "$ref" => "#/components/schemas/MatchReport" } }
        let(:id) { finished_report.id }
        run_test!
      end

      response "404", "someone else's report" do
        schema "$ref" => "#/components/schemas/Problem"
        let(:id) do
          other = create(:job_posting)
          other.match_reports.create!(user: other.user, version: 1).id
        end
        run_test!
      end
    end
  end

  it "needs a library before running", :ai do
    create(:requirement, job_posting: posting, text: "Rails")
    post "/api/v1/job_postings/#{posting.id}/match_reports"
    expect(json["title"]).to eq("Library is empty")
  end

  it "can't run on someone else's posting", :ai do
    post "/api/v1/job_postings/#{create(:job_posting).id}/match_reports"
    expect(response).to have_http_status(:not_found)
  end
end
