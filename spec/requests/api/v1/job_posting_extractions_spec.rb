require "swagger_helper"

RSpec.describe "Job posting AI extraction API", type: :request do
  let(:user) { create(:user) }
  let(:posting) { create(:job_posting, user:) }
  let(:job_posting_id) { posting.id }

  before { sign_in(user) }

  path "/api/v1/job_postings/{job_posting_id}/extraction" do
    parameter name: :job_posting_id, in: :path, type: :integer

    post "Read the posting with AI to fill in fields and requirements" do
      tags "Job postings"
      produces "application/json"
      security [ { session_cookie: [], csrf_token: [] } ]
      description <<~TEXT
        Runs in the background. Poll GET /api/v1/job_postings/{id} until extraction.status is "done" or "failed".
        Fills empty fields only and adds requirements that aren't listed yet. Needs a confirmed email;
        limited to #{AiUsage.daily_limit} runs per user per day.
      TEXT

      response "202", "started", ai: true do
        schema "$ref" => "#/components/schemas/JobPostingEnvelope"

        run_test! do
          expect(json["job_posting"]["extraction"]["status"]).to eq("pending")
          expect(ExtractPostingJob).to have_been_enqueued.with(posting.id)
        end
      end

      response "403", "email not confirmed", ai: true do
        schema "$ref" => "#/components/schemas/Problem"
        let(:user) { create(:user, :unverified) }
        run_test!
      end

      response "409", "already running", ai: true do
        schema "$ref" => "#/components/schemas/Problem"
        before { posting.update!(extraction_status: "pending") }
        run_test!
      end

      response "429", "daily limit reached", ai: true do
        schema "$ref" => "#/components/schemas/Problem"
        before { AiUsage.daily_limit.times { AiUsage.create!(user:, feature: "posting_extraction", model: "claude-opus-5-5") } }
        run_test!
      end

      response "503", "AI not configured on the server" do
        schema "$ref" => "#/components/schemas/Problem"
        around { |example| with_env("ANTHROPIC_API_KEY" => nil) { example.run } }
        run_test!
      end
    end
  end

  it "can't start extraction on someone else's posting", ai: true do
    post "/api/v1/job_postings/#{create(:job_posting).id}/extraction"
    expect(response).to have_http_status(:not_found)
  end
end
