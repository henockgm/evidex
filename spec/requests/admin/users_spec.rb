require "rails_helper"

RSpec.describe "Admin users list", type: :request do
  let(:admin) { create(:user, :admin, email_address: "admin@example.com", created_at: 2.days.ago) }

  before { sign_in(admin) }

  it "lists accounts newest first with sign-in and usage figures" do
    ada = create(:user, :oauth_only, email_address: "ada@example.com", name: "Ada")
    create(:session, user: ada, last_active_at: 1.hour.ago)
    create(:session, user: ada, last_active_at: 20.days.ago) # idle, no longer active
    AiUsage.create!(user: ada, feature: "match_report", model: "claude-opus-5-5")
    AiUsage.create!(user: ada, feature: "match_report", model: "claude-opus-5-5", created_at: 31.days.ago)

    get "/api/v1/admin/users"

    expect(json["users"].pluck("email_address")).to eq(%w[ada@example.com admin@example.com])
    expect(json["users"].first).to include(
      "name" => "Ada", "admin" => false, "has_password" => false, "two_factor_enabled" => false,
      "providers" => [ "google_oauth2" ], "active_sessions" => 1, "ai_calls_last_30_days" => 1, "locked_until" => nil
    )
    expect(Time.zone.parse(json["users"].first["last_active_at"])).to be_within(1.second).of(1.hour.ago)
    expect(json["users"].last).to include("admin" => true, "two_factor_enabled" => true, "active_sessions" => 1)
  end

  it "searches by email or name" do
    create(:user, email_address: "grace@example.com", name: "Grace Hopper")
    create(:user, email_address: "linus@example.com", name: "Linus")

    get "/api/v1/admin/users", params: { q: "hopper" }
    expect(json["users"].pluck("email_address")).to eq(%w[grace@example.com])

    get "/api/v1/admin/users", params: { q: "LINUS@" }
    expect(json["users"].pluck("email_address")).to eq(%w[linus@example.com])

    get "/api/v1/admin/users", params: { q: "%" }
    expect(json["users"]).to be_empty
  end

  it "pages 25 at a time" do
    create_list(:user, 25)

    get "/api/v1/admin/users", params: { page: 2 }

    expect(json["users"].size).to eq(1)
    expect(json["meta"]).to include("page" => 2, "total" => 26, "total_pages" => 2)
  end

  it "shows a temporary sign-in lock" do
    create(:user, locked_until: 10.minutes.from_now)

    get "/api/v1/admin/users"

    expect(json["users"].first["locked_until"]).to be_present
  end

  it "is for admins only" do
    delete "/api/v1/session"
    sign_in(create(:user))

    get "/api/v1/admin/users"

    expect(response).to have_http_status(:not_found)
  end
end
