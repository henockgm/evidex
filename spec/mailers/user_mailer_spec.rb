require "rails_helper"

RSpec.describe UserMailer do
  let(:user) { create(:user) }

  it "describes a sign-in from a new device" do
    mail = described_class.with(user:, at: Time.utc(2026, 10, 22, 9, 5), ip_address: "203.0.113.7",
      user_agent: "Mozilla/5.0 (Windows NT 10.0; Win64; x64) Gecko/20100101 Firefox/140.0").new_device_sign_in

    expect(mail.to).to eq([ user.email_address ])
    expect(mail.subject).to eq("New sign-in to your Evidex account")
    expect(mail.body.encoded).to include("Firefox on Windows", "203.0.113.7", "22 October 2026, 09:05 UTC", "/forgot-password")
  end

  it "says how many recovery codes are left" do
    RecoveryCode.regenerate_for!(user)
    RecoveryCode.where(id: user.recovery_codes.reload.first(9)).update_all(used_at: Time.current)

    expect(described_class.with(user:).recovery_code_used.body.encoded).to include("You have 1 left.")
  end

  it "tells a locked-out user who to contact" do
    mail = described_class.with(user:).account_suspended

    expect(mail.subject).to eq("Your Evidex account has been locked")
    expect(mail.body.encoded).to include("signed out on all devices", "contact the person who runs this Evidex site")
  end

  it "names the disconnected provider" do
    mail = described_class.with(user:, provider: "entra_id").identity_unlinked

    expect(mail.subject).to eq("Microsoft sign-in was disconnected from your Evidex account")
  end
end

RSpec.describe DeviceName do
  it "names common browsers" do
    expect(described_class.for("Mozilla/5.0 (Macintosh; Intel Mac OS X 14_0) AppleWebKit/537.36 Chrome/140.0 Safari/537.36")).to eq("Chrome on macOS")
    expect(described_class.for("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) Version/18.0 Mobile Safari/604.1")).to eq("Safari on iOS")
    expect(described_class.for("Mozilla/5.0 (Linux; Android 15; Pixel 9) Chrome/140.0 Mobile Safari/537.36")).to eq("Chrome on Android")
    expect(described_class.for(nil)).to eq("Unknown device")
  end
end
