require "rails_helper"

RSpec.describe "Security emails", type: :request do
  let(:user) { create(:user) }

  def new_browser = reset!

  describe "sign-in from a new device" do
    it "isn't sent for the first device or one seen before" do
      expect { sign_in(user) }.not_to have_enqueued_mail(UserMailer, :new_device_sign_in)

      delete "/api/v1/session"
      expect { sign_in(user) }.not_to have_enqueued_mail(UserMailer, :new_device_sign_in)
      expect(user.known_devices.count).to eq(1)
    end

    it "is sent when another browser signs in" do
      sign_in(user)
      new_browser

      expect { sign_in(user) }.to have_enqueued_mail(UserMailer, :new_device_sign_in)
      expect(user.known_devices.count).to eq(2)
    end

    it "is sent only after the second factor, for 2FA users" do
      sign_in(user)
      secret = ROTP::Base32.random
      user.enable_two_factor!(secret)
      new_browser

      expect { post "/api/v1/session", params: { email_address: user.email_address, password: AuthHelpers::PASSWORD }, as: :json }
        .not_to have_enqueued_mail(UserMailer, :new_device_sign_in)
      expect { post "/api/v1/session/second_factor", params: { code: ROTP::TOTP.new(secret).now }, as: :json }
        .to have_enqueued_mail(UserMailer, :new_device_sign_in)
    end

    it "keeps devices of different users apart" do
      other = create(:user)
      sign_in(other)
      delete "/api/v1/session"

      expect { sign_in(user) }.not_to have_enqueued_mail(UserMailer, :new_device_sign_in)
    end
  end

  context "when signed in" do
    before { sign_in(user) }

    it "tells the user when two-factor sign-in is turned on, codes are replaced and it's turned off" do
      post "/api/v1/me/two_factor/setup"
      secret = json["secret"]
      expect { post "/api/v1/me/two_factor", params: { code: ROTP::TOTP.new(secret).now }, as: :json }
        .to have_enqueued_mail(UserMailer, :two_factor_enabled)
      expect { post "/api/v1/me/two_factor/recovery_codes" }.to have_enqueued_mail(UserMailer, :recovery_codes_regenerated)
      expect { delete "/api/v1/me/two_factor" }.to have_enqueued_mail(UserMailer, :two_factor_disabled)
    end

    it "tells the user when a provider is disconnected" do
      identity = create(:identity, user:)

      expect { delete "/api/v1/me/identities/#{identity.id}" }.to have_enqueued_mail(UserMailer, :identity_unlinked)
    end
  end

  it "tells the user when a recovery code is used to sign in, but not for an app code" do
    secret = ROTP::Base32.random
    user.enable_two_factor!(secret)
    code = RecoveryCode.regenerate_for!(user).first
    password_step = -> { post "/api/v1/session", params: { email_address: user.email_address, password: AuthHelpers::PASSWORD }, as: :json }

    password_step.call
    expect { post "/api/v1/session/second_factor", params: { code: ROTP::TOTP.new(secret).now }, as: :json }
      .not_to have_enqueued_mail(UserMailer, :recovery_code_used)

    delete "/api/v1/session"
    password_step.call
    expect { post "/api/v1/session/second_factor", params: { code: }, as: :json }
      .to have_enqueued_mail(UserMailer, :recovery_code_used)
  end
end
