# A one-time code for signing in when the authenticator app isn't available.
# Codes are random, so a SHA-256 digest is enough to store them safely.
class RecoveryCode < ApplicationRecord
  COUNT = 10

  belongs_to :user

  scope :unused, -> { where(used_at: nil) }

  def self.digest(code)
    OpenSSL::Digest::SHA256.hexdigest(normalize(code))
  end

  def self.normalize(code)
    code.to_s.downcase.gsub(/[^a-z0-9]/, "")
  end

  # Replaces the user's codes; returns the new plain codes (shown once).
  def self.regenerate_for!(user)
    codes = Array.new(COUNT) { SecureRandom.alphanumeric(10).downcase.scan(/.{5}/).join("-") }
    transaction do
      user.recovery_codes.delete_all
      now = Time.current
      insert_all!(codes.map { |code| { user_id: user.id, code_digest: digest(code), created_at: now } })
    end
    codes
  end

  # Marks a matching unused code as used; true if one was found.
  def self.consume!(user, code)
    user.recovery_codes.unused.where(code_digest: digest(code)).update_all(used_at: Time.current) == 1
  end
end
