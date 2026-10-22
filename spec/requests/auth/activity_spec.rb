require "rails_helper"

RSpec.describe "Security activity", type: :request do
  let(:user) { create(:user) }

  before { sign_in(user) }

  it "lists the user's own events, newest first, with readable devices and safe details" do
    AuditEvent.create!(user:, action: "session_revoked", metadata: { "session_id" => 42 }, created_at: 1.minute.from_now,
      user_agent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) Chrome/140.0", ip_address: "203.0.113.7")
    AuditEvent.create!(user: create(:user), action: "signed_in")

    get "/api/v1/me/activity"

    expect(json["events"].pluck("action")).to eq(%w[session_revoked signed_in])
    expect(json["events"].first).to include("device" => "Chrome on macOS", "ip_address" => "203.0.113.7", "details" => {})
    expect(json["meta"]).to include("total" => 2, "total_pages" => 1)
  end

  it "pages through 20 at a time" do
    21.times { |i| AuditEvent.create!(user:, action: "signed_out", created_at: i.minutes.ago) }

    get "/api/v1/me/activity", params: { page: 2 }

    expect(json["events"].size).to eq(2)
    expect(json["meta"]).to include("page" => 2, "total" => 22, "total_pages" => 2)
  end

  it "needs a signed-in user" do
    delete "/api/v1/session"
    get "/api/v1/me/activity"

    expect(response).to have_http_status(:unauthorized)
  end
end
