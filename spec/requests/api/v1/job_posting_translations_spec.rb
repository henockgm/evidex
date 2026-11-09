require "swagger_helper"

RSpec.describe "Job posting requirement translation API", type: :request do
  let(:user) { create(:user) }
  let(:posting) { create(:job_posting, user:, extracted_at: 1.week.ago, extraction_status: "done") }
  let(:job_posting_id) { posting.id }
  let!(:requirement) { create(:requirement, job_posting: posting, kind: "required", text: "Kokemus tietokannoista") }

  before { sign_in(user) }

  path "/api/v1/job_postings/{job_posting_id}/translation" do
    parameter name: :job_posting_id, in: :path, type: :integer

    post "Translate the posting's requirements into English" do
      tags "Job postings"
      produces "application/json"
      security [ { session_cookie: [], csrf_token: [] } ]
      description <<~TEXT
        For postings read before Evidex started reading ads into English. Detects the ad's language,
        moves each requirement's wording to source_text and puts the English in text. Requirements that
        already have source_text are left alone. Runs in the request; counts toward the daily AI limit.
      TEXT

      response "200", "translated", ai: true do
        schema "$ref" => "#/components/schemas/JobPostingEnvelope"
        before { stub_claude(json: { language: "fi", translations: [ { id: "R1", text: "Experience with databases" } ] }) }

        run_test! do
          expect(json["job_posting"]["language"]).to eq("fi")
          expect(json["job_posting"]["requirements"].sole).to include("text" => "Experience with databases", "source_text" => "Kokemus tietokannoista")
          expect(AiUsage.sole.feature).to eq("requirement_translation")
        end
      end

      response "403", "email not confirmed", ai: true do
        schema "$ref" => "#/components/schemas/Problem"
        let(:user) { create(:user, :unverified) }
        run_test!
      end

      response "409", "posting is being read", ai: true do
        schema "$ref" => "#/components/schemas/Problem"
        before { posting.update!(extraction_status: "pending") }
        run_test!
      end

      response "422", "nothing to translate", ai: true do
        schema "$ref" => "#/components/schemas/Problem"
        before { requirement.update!(source_text: "Kokemus tietokannoista", text: "Experience with databases") }
        run_test!
      end

      response "429", "daily limit reached", ai: true do
        schema "$ref" => "#/components/schemas/Problem"
        before { AiUsage.daily_limit.times { AiUsage.create!(user:, feature: "posting_extraction", model: "claude-opus-5-5") } }
        run_test!
      end

      response "502", "the AI call failed", ai: true do
        schema "$ref" => "#/components/schemas/Problem"
        before { stub_claude(json: {}, stop_reason: "refusal") }
        run_test!
      end

      response "503", "AI not configured on the server" do
        schema "$ref" => "#/components/schemas/Problem"
        around { |example| with_env("ANTHROPIC_API_KEY" => nil) { example.run } }
        run_test!
      end
    end
  end

  it "leaves an English posting as it is and remembers its language", ai: true do
    requirement.update!(text: "Experience with databases")
    stub_claude(json: { language: "en", translations: [ { id: "R1", text: "Experience with databases" } ] })

    post "/api/v1/job_postings/#{posting.id}/translation"

    expect(posting.reload.language).to eq("en")
    expect(requirement.reload).to have_attributes(text: "Experience with databases", source_text: nil)
  end

  it "only sends requirements that aren't translated yet, and keeps the others", ai: true do
    translated = create(:requirement, job_posting: posting, kind: "preferred", text: "Python", source_text: "Python-osaaminen")
    stub = stub_claude(json: { language: "fi", translations: [ { id: "R1", text: "Experience with databases" }, { id: "R9", text: "Ignored" } ] })

    post "/api/v1/job_postings/#{posting.id}/translation"

    expect(stub.with { |request|
      content = JSON.parse(request.body)["messages"].first["content"]
      content == "<requirements>\nR1 Kokemus tietokannoista\n</requirements>"
    }).to have_been_requested
    expect(translated.reload).to have_attributes(text: "Python", source_text: "Python-osaaminen")
    expect(requirement.reload.text).to eq("Experience with databases")
  end

  it "can't translate someone else's posting", ai: true do
    post "/api/v1/job_postings/#{create(:job_posting).id}/translation"
    expect(response).to have_http_status(:not_found)
  end
end
