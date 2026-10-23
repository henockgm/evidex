require "rails_helper"

RSpec.describe "Admin lock, unlock and force sign-out", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:target) { create(:user, email_address: "ada@example.com") }

  before { sign_in(admin) }

  def sign_in_elsewhere(user)
    # A session on another device: a separate cookie jar.
    session = open_session
    session.post "/api/v1/session", params: { email_address: user.email_address, password: AuthHelpers::PASSWORD }, as: :json
    session.post "/api/v1/session/second_factor", params: { code: ROTP::TOTP.new(user.reload.otp_secret).now }, as: :json if user.two_factor_enabled?
    expect(session.response).to have_http_status(:created)
    session
  end

  describe "locking" do
    it "signs the user out everywhere, blocks sign-in, emails them and records who did it" do
      device = sign_in_elsewhere(target)

      expect { post "/api/v1/admin/users/#{target.id}/lock", as: :json }
        .to have_enqueued_mail(UserMailer, :account_suspended)

      expect(response).to have_http_status(:ok)
      expect(json["user"]["suspended_at"]).to be_present
      expect(json["user"]["last_active_at"]).to be_present # from the sign-in, though its session is gone
      expect(target.reload.sessions).to be_empty
      expect(AuditEvent.where(user: target, action: "admin_locked").last.metadata).to eq("admin_id" => admin.id)

      device.get "/api/v1/me"
      expect(device.response).to have_http_status(:unauthorized)

      device.post "/api/v1/session", params: { email_address: target.email_address, password: AuthHelpers::PASSWORD }, as: :json
      expect(device.response).to have_http_status(:unauthorized)
    end

    it "blocks Google and Microsoft sign-in too" do
      oauth_user = create(:user, :oauth_only)
      post "/api/v1/admin/users/#{oauth_user.id}/lock", as: :json
      identity = oauth_user.identities.first

      delete "/api/v1/session"
      mock_google(uid: identity.uid, email: oauth_user.email_address)
      oauth_sign_in(:google_oauth2)

      expect(response).to redirect_to("/login?error=account_suspended")
      expect(oauth_user.sessions.reload).to be_empty
    end

    it "keeps a session from resuming even if one slipped through" do
      device = sign_in_elsewhere(target)
      target.update_column(:suspended_at, Time.current)

      device.get "/api/v1/me"

      expect(device.response).to have_http_status(:unauthorized)
    end

    it "doesn't let admins lock themselves out" do
      post "/api/v1/admin/users/#{admin.id}/lock", as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(admin.reload).not_to be_suspended
    end

    it "needs a recent sign-in" do
      travel 11.minutes

      post "/api/v1/admin/users/#{target.id}/lock", as: :json

      expect(response).to have_http_status(:forbidden)
      expect(json["type"]).to eq("urn:evidex:problem:reauthentication-required")
      expect(target.reload).not_to be_suspended
    end
  end

  describe "unlocking" do
    it "lets the user sign in again and also lifts a lock after failed attempts" do
      target.update!(suspended_at: Time.current, locked_until: 1.hour.from_now, failed_sign_in_count: 3)

      delete "/api/v1/admin/users/#{target.id}/lock", as: :json

      expect(json["user"]).to include("suspended_at" => nil, "locked_until" => nil)
      expect(AuditEvent.where(user: target, action: "admin_unlocked")).to exist
      sign_in_elsewhere(target)
    end
  end

  describe "force sign-out" do
    it "ends every session without locking the account" do
      sign_in_elsewhere(target)
      sign_in_elsewhere(target)

      post "/api/v1/admin/users/#{target.id}/sign_out", as: :json

      expect(json["user"]).to include("active_sessions" => 0, "suspended_at" => nil)
      expect(AuditEvent.where(user: target, action: "admin_signed_out").last.metadata).to include("admin_id" => admin.id, "sessions" => 2)
      sign_in_elsewhere(target)
    end

    it "shows on the user's own activity page without naming the admin" do
      post "/api/v1/admin/users/#{target.id}/sign_out", as: :json
      device = sign_in_elsewhere(target)

      device.get "/api/v1/me/activity"

      event = device.response.parsed_body["events"].find { |e| e["action"] == "admin_signed_out" }
      expect(event["details"]).to eq({})
    end
  end

  it "is for admins only" do
    delete "/api/v1/session"
    sign_in(create(:user))

    post "/api/v1/admin/users/#{target.id}/lock", as: :json

    expect(response).to have_http_status(:not_found)
    expect(target.reload).not_to be_suspended
  end
end
