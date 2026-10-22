require "rails_helper"

RSpec.describe "Two-factor authentication on User" do
  let(:user) { create(:user) }
  let(:secret) { ROTP::Base32.random }

  it "stores the secret encrypted" do
    user.update!(otp_secret: secret)
    raw = ActiveRecord::Base.connection.select_value("SELECT otp_secret FROM users WHERE id = #{user.id}")

    expect(raw).not_to include(secret)
    expect(user.reload.otp_secret).to eq(secret)
  end

  it "turns on with recovery codes stored only as digests" do
    codes = user.enable_two_factor!(secret)

    expect(user).to be_two_factor_enabled
    expect(codes.size).to eq(10)
    expect(codes).to all(match(/\A[a-z0-9]{5}-[a-z0-9]{5}\z/))
    expect(user.recovery_codes.pluck(:code_digest)).not_to include(*codes)
  end

  it "accepts a current code once (no replay)" do
    user.enable_two_factor!(secret)
    code = ROTP::TOTP.new(secret).now

    expect(user.verify_second_factor!(code)).to be(true)
    expect(user.verify_second_factor!(code)).to be(false)
  end

  it "rejects malformed and stale codes" do
    user.enable_two_factor!(secret)

    expect(user.verify_otp!("12345")).to be(false)
    expect(user.verify_otp!("abcdef")).to be(false)
    expect(user.verify_otp!(ROTP::TOTP.new(secret).at(10.minutes.ago))).to be(false)
  end

  it "accepts each recovery code once, ignoring case and dashes" do
    code = user.enable_two_factor!(secret).first

    expect(user.verify_second_factor!(code.upcase.delete("-"))).to be(true)
    expect(user.verify_second_factor!(code)).to be(false)
    expect(user.recovery_codes.unused.count).to eq(9)
  end

  it "turns off and forgets the secret and codes" do
    user.enable_two_factor!(secret)
    user.disable_two_factor!

    expect(user.reload).to have_attributes(two_factor_enabled?: false, otp_secret: nil)
    expect(user.recovery_codes).to be_empty
  end
end
