require "rails_helper"

RSpec.describe "Admin audit log and AI usage", type: :request do
  let(:admin) { create(:user, :admin, email_address: "admin@example.com") }
  let(:ada) { create(:user, email_address: "ada@example.com") }

  before { sign_in(admin) }

  describe "audit log" do
    it "lists events across accounts, newest first, naming the admin behind admin actions" do
      AuditEvent.create!(user: ada, action: "sign_in_failed", ip_address: "203.0.113.7", created_at: 2.minutes.ago)
      AuditEvent.create!(user: nil, action: "sign_in_failed", created_at: 1.minute.ago)
      AuditEvent.create!(user: ada, action: "admin_signed_out", metadata: { "admin_id" => admin.id, "sessions" => 2 })

      get "/api/v1/admin/audit_events"

      events = json["events"]
      expect(events.first).to include("action" => "admin_signed_out", "admin_email_address" => "admin@example.com",
        "details" => { "sessions" => 2 }, "user" => { "id" => ada.id, "email_address" => "ada@example.com" })
      expect(events.find { |e| e["user"].nil? }).to include("action" => "sign_in_failed")
      expect(events.pluck("action")).to include("sign_in_failed", "signed_in") # the admin's own sign-in
    end

    it "filters by account and action" do
      AuditEvent.create!(user: ada, action: "sign_in_failed")
      AuditEvent.create!(user: ada, action: "signed_out")
      AuditEvent.create!(user: create(:user), action: "sign_in_failed")

      get "/api/v1/admin/audit_events", params: { user_id: ada.id, event_action: "sign_in_failed" }

      expect(json["events"].size).to eq(1)
      expect(json["meta"]["total"]).to eq(1)
    end
  end

  describe "AI usage" do
    def usage(user, model:, input:, output:, at: Time.current, succeeded: true)
      AiUsage.create!(user:, feature: "match_report", model:, input_tokens: input, output_tokens: output, created_at: at, succeeded:)
    end

    it "totals calls, tokens and estimated cost per account for the period" do
      grace = create(:user, email_address: "grace@example.com")
      usage(ada, model: "claude-opus-5-5", input: 1_000_000, output: 100_000)           # $4 + $2
      usage(ada, model: "claude-opus-5-5", input: 0, output: 0, succeeded: false)
      usage(grace, model: "claude-haiku-5-5", input: 2_000_000, output: 0)               # $0.20
      usage(grace, model: "some-future-model", input: 500, output: 500)
      usage(grace, model: "claude-opus-5-5", input: 1_000_000, output: 0, at: 40.days.ago) # outside 30 days

      get "/api/v1/admin/ai_usage"

      expect(json["days"]).to eq(30)
      expect(json["totals"]).to include("calls" => 4, "failed_calls" => 1, "input_tokens" => 3_000_500,
        "estimated_cost_usd" => 6.2, "unpriced_models" => [ "some-future-model" ])
      expect(json["users"].map { |u| [ u["user"]["email_address"], u["calls"], u["estimated_cost_usd"] ] })
        .to eq([ [ "ada@example.com", 2, 6.0 ], [ "grace@example.com", 2, 0.2 ] ])
    end

    it "looks back 7 or 90 days on request" do
      usage(ada, model: "claude-opus-5-5", input: 1, output: 1, at: 40.days.ago)

      get "/api/v1/admin/ai_usage", params: { days: 90 }
      expect(json["totals"]["calls"]).to eq(1)

      get "/api/v1/admin/ai_usage", params: { days: 7 }
      expect(json).to include("days" => 7, "users" => [])
    end
  end

  it "is for admins only" do
    delete "/api/v1/session"
    sign_in(create(:user))

    get "/api/v1/admin/audit_events"
    expect(response).to have_http_status(:not_found)

    get "/api/v1/admin/ai_usage"
    expect(response).to have_http_status(:not_found)
  end
end
