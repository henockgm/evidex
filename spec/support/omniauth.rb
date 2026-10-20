OmniAuth.config.test_mode = true

module OmniauthHelpers
  def mock_google(uid: "google-123", email: "ada@example.com", verified: true, name: "Ada Lovelace")
    OmniAuth.config.mock_auth[:google_oauth2] = OmniAuth::AuthHash.new(
      provider: "google_oauth2", uid:,
      info: { email: (email if verified), unverified_email: email, email_verified: verified, name: },
      extra: { raw_info: { email:, email_verified: verified } }
    )
  end

  def mock_microsoft(uid: "tenant-oid-123", email: "ada@example.com", name: "Ada Lovelace")
    OmniAuth.config.mock_auth[:entra_id] = OmniAuth::AuthHash.new(
      provider: "entra_id", uid:, info: { email:, name: }, extra: { raw_info: { email: } }
    )
  end

  # Request phase (POST, as the SPA does) followed by the provider redirecting back.
  def oauth_sign_in(provider)
    post "/auth/#{provider}"
    follow_redirect!
  end
end

RSpec.configure do |config|
  config.include OmniauthHelpers, type: :request
  config.after { OmniAuth.config.mock_auth.except!(:google_oauth2, :entra_id) }
end
