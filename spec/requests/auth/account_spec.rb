require "rails_helper"

RSpec.describe "Account security settings", type: :request do
  let(:user) { create(:user) }

  before { sign_in(user) }

  describe "sessions" do
    it "lists active sessions and marks the current one" do
      create(:session, user:, user_agent: "Other laptop")

      get "/api/v1/me/sessions"

      expect(json["sessions"].size).to eq(2)
      expect(json["sessions"].count { |s| s["current"] }).to eq(1)
    end

    it "revokes another session" do
      other = create(:session, user:)

      delete "/api/v1/me/sessions/#{other.id}"

      expect(response).to have_http_status(:no_content)
      expect(Session.exists?(other.id)).to be(false)
    end

    it "revokes all other sessions but keeps this one" do
      create_list(:session, 2, user:)

      delete "/api/v1/me/sessions/others"

      expect(user.sessions.count).to eq(1)
      get "/api/v1/me"
      expect(response).to have_http_status(:ok)
    end

    it "can't touch another user's sessions" do
      stranger = create(:session)

      delete "/api/v1/me/sessions/#{stranger.id}"

      expect(response).to have_http_status(:not_found)
      expect(Session.exists?(stranger.id)).to be(true)
    end
  end

  describe "password change" do
    let(:new_password) { "an even longer new password" }

    it "requires the current password" do
      patch "/api/v1/me/password", params: { current_password: "wrong password!!", password: new_password }, as: :json

      expect(response).to have_http_status(:unprocessable_content)
      expect(json["errors"]).to have_key("current_password")
    end

    it "changes the password and signs out other devices" do
      other = create(:session, user:)

      expect { patch "/api/v1/me/password", params: { current_password: AuthHelpers::PASSWORD, password: new_password }, as: :json }
        .to have_enqueued_mail(UserMailer, :password_changed)

      expect(response).to have_http_status(:ok)
      expect(user.reload.authenticate(new_password)).to be_truthy
      expect(Session.exists?(other.id)).to be(false)
    end
  end

  describe "sign-in methods" do
    it "unlinks a provider when a password remains" do
      identity = create(:identity, user:)

      delete "/api/v1/me/identities/#{identity.id}"

      expect(response).to have_http_status(:no_content)
    end

    it "refuses to remove the last sign-in method" do
      oauth_user = create(:user, :oauth_only)
      delete "/api/v1/session"
      mock_google(uid: oauth_user.identities.sole.uid, email: oauth_user.email_address)
      oauth_sign_in(:google_oauth2)

      delete "/api/v1/me/identities/#{oauth_user.identities.sole.id}"

      expect(response).to have_http_status(:unprocessable_content)
      expect(oauth_user.identities.count).to eq(1)
    end

    it "lets an OAuth-only account add a password right after signing in" do
      oauth_user = create(:user, :oauth_only)
      delete "/api/v1/session"
      mock_google(uid: oauth_user.identities.sole.uid, email: oauth_user.email_address)
      oauth_sign_in(:google_oauth2)

      patch "/api/v1/me/password", params: { password: "my first real password" }, as: :json
      expect(response).to have_http_status(:ok)

      travel 11.minutes do
        oauth_user.update_columns(password_digest: nil)
        patch "/api/v1/me/password", params: { password: "my first real password" }, as: :json
        expect(response).to have_http_status(:forbidden)
      end
    end
  end

  describe "account deletion" do
    it "requires the password" do
      delete "/api/v1/me", params: { password: "wrong password!!" }, as: :json
      expect(response).to have_http_status(:unprocessable_content)
      expect(User.exists?(user.id)).to be(true)
    end

    it "deletes the user and all their data" do
      create(:identity, user:)

      delete "/api/v1/me", params: { password: AuthHelpers::PASSWORD }, as: :json

      expect(response).to have_http_status(:no_content)
      expect(User.exists?(user.id)).to be(false)
      expect(Session.where(user_id: user.id)).to be_empty
      expect(Identity.where(user_id: user.id)).to be_empty
      expect(AuditEvent.where(user_id: user.id)).to be_empty
    end
  end
end
