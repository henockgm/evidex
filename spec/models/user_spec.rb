require "rails_helper"

RSpec.describe User do
  subject(:user) { build(:user) }

  it { is_expected.to validate_presence_of(:email_address) }
  it { is_expected.to validate_uniqueness_of(:email_address).case_insensitive }
  it { is_expected.to validate_length_of(:name).is_at_most(100) }

  it "normalizes the email address" do
    expect(described_class.new(email_address: "  Ada@Example.COM ").email_address).to eq("ada@example.com")
  end

  it "rejects malformed email addresses" do
    user.email_address = "not-an-email"
    expect(user).not_to be_valid
  end

  describe "password rules" do
    it "requires a password when registering" do
      user.password = nil
      expect(user.valid?(:registration)).to be(false)
      expect(user.errors[:password]).to include("can't be blank")
    end

    it "allows OAuth-only accounts without a password" do
      user.password = nil
      expect(user).to be_valid
      expect(user).not_to be_password
    end

    it "requires at least 12 characters" do
      user.password = "short-pass1"
      expect(user).not_to be_valid
      expect(user.errors[:password]).to include("is too short (minimum is 12 characters)")
    end

    it "rejects passwords longer than 72 bytes" do
      user.password = "é" * 37
      expect(user).not_to be_valid
    end

    it "rejects breached passwords when the check is on" do
      allow(Rails.configuration.x).to receive(:pwned_passwords_check).and_return(true)
      allow(PwnedPasswords).to receive(:breached?).with("password1234").and_return(true)

      user.password = "password1234"
      expect(user).not_to be_valid
      expect(user.errors[:password].join).to include("data breach")
    end
  end

  describe "email verification token" do
    let(:user) { create(:user, :unverified) }

    it "finds the user and stops working once used" do
      token = user.generate_token_for(:email_verification)
      expect(described_class.find_by_token_for(:email_verification, token)).to eq(user)

      user.verify_email!
      expect(described_class.find_by_token_for(:email_verification, token)).to be_nil
    end

    it "expires after 24 hours" do
      token = user.generate_token_for(:email_verification)
      travel 25.hours do
        expect(described_class.find_by_token_for(:email_verification, token)).to be_nil
      end
    end
  end

  describe "#register_failed_sign_in!" do
    let(:user) { create(:user) }

    it "locks the account after 5 failures" do
      4.times { expect(user.register_failed_sign_in!).to be(false) }
      expect(user.register_failed_sign_in!).to be(true)

      expect(user).to be_locked
      expect(user.locked_until).to be_within(5.seconds).of(15.minutes.from_now)
    end

    it "doubles each consecutive lockout" do
      user.update_columns(lockout_count: 2)
      5.times { user.register_failed_sign_in! }

      expect(user.locked_until).to be_within(5.seconds).of(60.minutes.from_now)
    end

    it "caps the lockout at 24 hours" do
      user.update_columns(lockout_count: 10)
      5.times { user.register_failed_sign_in! }

      expect(user.locked_until).to be_within(5.seconds).of(24.hours.from_now)
    end
  end
end
