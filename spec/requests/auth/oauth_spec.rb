require "rails_helper"

RSpec.describe "Google and Microsoft sign-in", type: :request do
  it "lists the configured providers" do
    get "/api/v1/auth/providers"
    expect(json["providers"].pluck("id")).to contain_exactly("google_oauth2", "entra_id")
  end

  it "only starts the OAuth flow with POST (prevents login CSRF via links)" do
    get "/auth/google_oauth2"
    expect(response).to have_http_status(:not_found)
  end

  context "with Google" do
    it "registers a verified account and signs in" do
      mock_google

      expect { oauth_sign_in(:google_oauth2) }.to change(User, :count).by(1)

      expect(response).to redirect_to("/")
      user = User.last
      expect(user).to be_verified
      expect(user).not_to be_password
      expect(user.identities.sole).to have_attributes(provider: "google_oauth2", uid: "google-123")

      get "/api/v1/me"
      expect(json["user"]["email_address"]).to eq("ada@example.com")
    end

    it "signs in an existing identity" do
      identity = create(:identity, uid: "google-123")
      mock_google

      expect { oauth_sign_in(:google_oauth2) }.not_to change(User, :count)
      get "/api/v1/me"
      expect(json["user"]["id"]).to eq(identity.user_id)
    end

    it "links to an existing account with the same verified email" do
      user = create(:user, email_address: "ada@example.com")
      mock_google

      expect { oauth_sign_in(:google_oauth2) }.to have_enqueued_mail(UserMailer, :identity_linked)
      expect(user.identities.count).to eq(1)
      expect(user.reload).to be_password
    end

    it "takes over an unverified password account safely (pre-hijacking defence)" do
      squatter = create(:user, :unverified, email_address: "ada@example.com")
      squatter_session = create(:session, user: squatter)
      mock_google

      oauth_sign_in(:google_oauth2)

      squatter.reload
      expect(squatter).to be_verified
      expect(squatter).not_to be_password
      expect(Session.exists?(squatter_session.id)).to be(false)
    end

    it "refuses to link by an unverified Google email" do
      create(:user, email_address: "ada@example.com")
      mock_google(verified: false)

      expect { oauth_sign_in(:google_oauth2) }.not_to change(Identity, :count)
      expect(response).to redirect_to("/login?error=account_exists")
    end
  end

  context "with Microsoft" do
    it "registers an unverified account and asks to confirm the email" do
      mock_microsoft

      expect { oauth_sign_in(:entra_id) }.to have_enqueued_mail(UserMailer, :email_verification)
      expect(User.last).not_to be_verified
    end

    it "never auto-links by email, because Microsoft emails aren't guaranteed verified" do
      create(:user, email_address: "ada@example.com")
      mock_microsoft

      expect { oauth_sign_in(:entra_id) }.not_to change(Identity, :count)
      expect(response).to redirect_to("/login?error=account_exists")
    end
  end

  context "when signed in" do
    let(:user) { create(:user) }

    before { sign_in(user) }

    it "connects another provider to the current account" do
      mock_microsoft(email: "different@example.com")

      oauth_sign_in(:entra_id)

      expect(response).to redirect_to("/settings/security?linked=entra_id")
      expect(user.identities.pluck(:provider)).to eq([ "entra_id" ])
    end

    it "refuses an identity that belongs to someone else" do
      create(:identity, provider: "entra_id", uid: "tenant-oid-123")
      mock_microsoft

      oauth_sign_in(:entra_id)

      expect(response).to redirect_to("/settings/security?error=identity_taken")
      expect(user.identities).to be_empty
    end
  end

  it "redirects provider errors back to the sign-in page" do
    OmniAuth.config.mock_auth[:google_oauth2] = :access_denied
    post "/auth/google_oauth2"
    follow_redirect!
    follow_redirect! while response.redirect? && !response.location.include?("/login")

    expect(response.location).to end_with("/login?error=oauth_failed")
  end
end
