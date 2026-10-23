require "rails_helper"
require "rake"

RSpec.describe "Admin access", type: :request do
  it "shows admins the overview" do
    admin = create(:user, :admin)
    create(:user, :unverified)
    sign_in(admin)

    get "/api/v1/admin/overview"

    expect(response).to have_http_status(:ok)
    expect(json).to include("users" => 2, "verified_users" => 1, "two_factor_users" => 1, "active_sessions" => 1)
  end

  it "hides the admin area from other users" do
    sign_in(create(:user))

    get "/api/v1/admin/overview"

    expect(response).to have_http_status(:not_found)
  end

  it "asks admins without two-factor sign-in to turn it on first" do
    sign_in(create(:user, admin: true))

    get "/api/v1/admin/overview"

    expect(response).to have_http_status(:forbidden)
    expect(json["type"]).to eq("urn:evidex:problem:two-factor-required")
  end

  it "needs a signed-in user" do
    get "/api/v1/admin/overview"

    expect(response).to have_http_status(:unauthorized)
  end

  it "tells the SPA who is an admin, and can't be changed through the API" do
    user = create(:user)
    sign_in(user)
    get "/api/v1/me"
    expect(json["user"]["admin"]).to be(false)

    patch "/api/v1/me/password", params: { admin: true, current_password: AuthHelpers::PASSWORD, password: "another long passphrase 42" }, as: :json
    expect(user.reload.admin?).to be(false)
  end

  describe "rake evidex:admin" do
    before(:context) { Rails.application.load_tasks unless Rake::Task.task_defined?("evidex:admin:grant") }

    def run(name, *args)
      Rake::Task[name].reenable
      expect { Rake::Task[name].invoke(*args) }.to output.to_stdout
    end

    it "grants and revokes admin rights by email" do
      user = create(:user, email_address: "ada@example.com")

      run("evidex:admin:grant", " Ada@Example.com ")
      expect(user.reload.admin?).to be(true)

      run("evidex:admin:revoke", "ada@example.com")
      expect(user.reload.admin?).to be(false)
    end
  end
end
