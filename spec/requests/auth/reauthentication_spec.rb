require "rails_helper"

RSpec.describe "Re-authentication (sudo mode)", type: :request do
  let(:user) { create(:user) }

  def reauthenticate(**params) = post("/api/v1/me/reauthentication", params:, as: :json)
  def change_password = patch("/api/v1/me/password", params: { password: "an even longer new password" }, as: :json)

  before { sign_in(user) }

  it "allows sensitive changes for 10 minutes after confirming the password" do
    travel 30.minutes
    change_password
    expect(response).to have_http_status(:forbidden)

    reauthenticate(password: "wrong password!!")
    expect(response).to have_http_status(:unprocessable_content)
    expect(json["errors"]).to have_key("password")
    expect(AuditEvent.last.action).to eq("reauthentication_failed")

    reauthenticate(password: AuthHelpers::PASSWORD)
    expect(response).to have_http_status(:created)
    expect(Time.zone.parse(json["recently_authenticated_until"])).to be_within(1.second).of(10.minutes.from_now)
    expect(AuditEvent.last.action).to eq("reauthenticated")

    travel 9.minutes
    change_password
    expect(response).to have_http_status(:ok)

    travel 2.minutes
    change_password
    expect(response).to have_http_status(:forbidden)
  end

  it "only extends the device it was confirmed on" do
    other = create(:session, user:, authenticated_at: 1.hour.ago)

    reauthenticate(password: AuthHelpers::PASSWORD)

    expect(other.reload).not_to be_recently_authenticated
  end

  context "with two-factor sign-in on" do
    let(:secret) { ROTP::Base32.random }

    before do
      user.enable_two_factor!(secret)
      travel 30.minutes
    end

    it "needs the password and a code" do
      reauthenticate(password: AuthHelpers::PASSWORD)
      expect(json["errors"]).to have_key("code")

      reauthenticate(password: AuthHelpers::PASSWORD, code: ROTP::TOTP.new(secret).now)
      expect(response).to have_http_status(:created)
    end

    it "accepts a recovery code once" do
      code = RecoveryCode.regenerate_for!(user).first

      reauthenticate(password: AuthHelpers::PASSWORD, code:)
      expect(response).to have_http_status(:created)

      reauthenticate(password: AuthHelpers::PASSWORD, code:)
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  context "with a Google-only account" do
    let(:user) { create(:user, :oauth_only) }

    def sign_in(user)
      mock_google(uid: user.identities.sole.uid, email: user.email_address)
      oauth_sign_in(:google_oauth2)
    end

    it "points to the connected account when there's no password or 2FA" do
      travel 30.minutes
      reauthenticate

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["title"]).to eq("Confirm with your connected account")
    end

    it "accepts a code when two-factor sign-in is on" do
      secret = ROTP::Base32.random
      user.enable_two_factor!(secret)
      travel 30.minutes

      reauthenticate(code: ROTP::TOTP.new(secret).now)

      expect(response).to have_http_status(:created)
    end
  end

  it "is limited to 5 attempts per 15 minutes" do
    5.times { reauthenticate(password: "wrong password!!") }
    reauthenticate(password: AuthHelpers::PASSWORD)

    expect(response).to have_http_status(:too_many_requests)
  end
end

RSpec.describe "Re-authentication with Google or Microsoft", type: :request do
  let(:user) { create(:user, :oauth_only) }
  let(:identity) { user.identities.sole }

  def reauthenticate_with_google(uid: identity.uid)
    mock_google(uid:, email: user.email_address)
    post "/auth/google_oauth2?intent=reauthenticate"
    follow_redirect!
  end

  before do
    mock_google(uid: identity.uid, email: user.email_address)
    oauth_sign_in(:google_oauth2)
    travel 30.minutes
  end

  it "confirms it's the user when they sign in again with a connected account" do
    reauthenticate_with_google

    expect(response).to redirect_to("/settings/security?reauthenticated=1")
    expect(AuditEvent.last).to have_attributes(action: "reauthenticated", metadata: { "provider" => "google_oauth2" })
    patch "/api/v1/me/password", params: { password: "my first real password" }, as: :json
    expect(response).to have_http_status(:ok)
  end

  it "refuses a provider account that isn't connected, without connecting it" do
    reauthenticate_with_google(uid: "someone-else")

    expect(response).to redirect_to("/settings/security?error=reauthentication_failed")
    expect(user.identities.count).to eq(1)
    patch "/api/v1/me/password", params: { password: "my first real password" }, as: :json
    expect(response).to have_http_status(:forbidden)
  end

  it "isn't enough when two-factor sign-in is on" do
    user.enable_two_factor!(ROTP::Base32.random)

    reauthenticate_with_google

    expect(response).to redirect_to("/settings/security?error=reauthentication_failed")
  end

  it "lists where to start it for each provider" do
    get "/api/v1/auth/providers"

    expect(json["providers"].pluck("reauthenticate_path"))
      .to eq([ "/auth/google_oauth2?intent=reauthenticate", "/auth/entra_id?intent=reauthenticate&prompt=login" ])
  end
end
