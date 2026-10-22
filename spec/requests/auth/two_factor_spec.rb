require "rails_helper"

RSpec.describe "Two-factor sign-in", type: :request do
  let(:user) { create(:user, :two_factor, email_address: "ada@example.com") }

  def code_for(user) = ROTP::TOTP.new(user.reload.otp_secret).now

  def password_step
    post "/api/v1/session", params: { email_address: user.email_address, password: AuthHelpers::PASSWORD }, as: :json
  end

  def second_step(code)
    post "/api/v1/session/second_factor", params: { code: }, as: :json
  end

  it "asks for a code after the password and signs in only once it's given" do
    password_step
    expect(response).to have_http_status(:accepted)
    expect(json).to eq("second_factor_required" => true)
    get "/api/v1/me"
    expect(response).to have_http_status(:unauthorized)

    second_step(code_for(user))
    expect(response).to have_http_status(:created)
    get "/api/v1/me"
    expect(json["user"]).to include("two_factor_enabled" => true, "recovery_codes_remaining" => 10)
    expect(AuditEvent.where(action: "signed_in").last.metadata).to include("second_factor" => "authenticator")
  end

  it "accepts a recovery code" do
    code = RecoveryCode.regenerate_for!(user).first
    password_step
    second_step(code)

    expect(response).to have_http_status(:created)
    expect(user.recovery_codes.unused.count).to eq(9)
  end

  it "rejects wrong codes, counts them toward lockout and gives up after 5 tries" do
    password_step
    4.times do
      second_step("000000")
      expect(response).to have_http_status(:unprocessable_content)
    end
    second_step("000000")

    expect(response).to have_http_status(:unauthorized)
    expect(json["title"]).to match(/Too many attempts|Sign-in expired/)
    expect(user.reload.locked?).to be(true)
    second_step(code_for(user))
    expect(response).to have_http_status(:unauthorized)
  end

  it "expires the half-finished sign-in after 5 minutes" do
    password_step
    travel 6.minutes do
      second_step(code_for(user))
      expect(response).to have_http_status(:unauthorized)
    end
  end

  it "can't be skipped by calling the second step directly" do
    second_step(code_for(user))
    expect(response).to have_http_status(:unauthorized)
  end

  it "also applies to Google sign-in" do
    create(:identity, user:, uid: "google-123")
    mock_google
    oauth_sign_in(:google_oauth2)

    expect(response).to redirect_to("/login/verify")
    get "/api/v1/me"
    expect(response).to have_http_status(:unauthorized)

    second_step(code_for(user))
    expect(response).to have_http_status(:created)
  end
end

RSpec.describe "Managing two-factor sign-in", type: :request do
  let(:user) { create(:user) }

  before { sign_in(user) }

  it "sets up with a QR code, confirms with a code and returns recovery codes once" do
    post "/api/v1/me/two_factor/setup"
    expect(json["qr_code"]).to start_with("data:image/svg+xml;base64,")
    expect(json["otpauth_uri"]).to start_with("otpauth://totp/Evidex:")
    secret = json["secret"]

    post "/api/v1/me/two_factor", params: { code: "000000" }, as: :json
    expect(response).to have_http_status(:unprocessable_content)

    post "/api/v1/me/two_factor", params: { code: ROTP::TOTP.new(secret).now }, as: :json
    expect(response).to have_http_status(:created)
    expect(json["recovery_codes"].size).to eq(10)
    expect(user.reload).to be_two_factor_enabled
    expect(AuditEvent.last.action).to eq("two_factor_enabled")
  end

  it "needs setup before confirming" do
    post "/api/v1/me/two_factor", params: { code: "123456" }, as: :json
    expect(json["title"]).to eq("Start again")
  end

  context "when two-factor is on" do
    let(:secret) { ROTP::Base32.random }

    before { user.enable_two_factor!(secret) }

    it "turns off with a valid code" do
      delete "/api/v1/me/two_factor", params: { code: "000000" }, as: :json
      expect(response).to have_http_status(:unprocessable_content)

      delete "/api/v1/me/two_factor", params: { code: ROTP::TOTP.new(secret).now }, as: :json
      expect(response).to have_http_status(:ok)
      expect(user.reload).not_to be_two_factor_enabled
    end

    it "replaces the recovery codes" do
      old = user.recovery_codes.pluck(:code_digest)
      post "/api/v1/me/two_factor/recovery_codes", params: { code: ROTP::TOTP.new(secret).now }, as: :json

      expect(json["recovery_codes"].size).to eq(10)
      expect(user.recovery_codes.reload.pluck(:code_digest) & old).to be_empty
    end

    it "refuses a second setup" do
      post "/api/v1/me/two_factor/setup"
      expect(response).to have_http_status(:conflict)
    end
  end
end
