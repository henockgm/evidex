# A signed-in device. The browser holds a random token in a signed, HttpOnly cookie;
# only its SHA-256 digest is stored, so a database leak doesn't expose usable sessions.
class Session < ApplicationRecord
  IDLE_TIMEOUT = 14.days
  ABSOLUTE_TIMEOUT = 30.days
  ACTIVITY_UPDATE_INTERVAL = 5.minutes
  RECENT_AUTHENTICATION = 10.minutes

  belongs_to :user

  attr_reader :token

  before_validation :generate_token, on: :create

  scope :active, -> { where(last_active_at: IDLE_TIMEOUT.ago..).where(created_at: ABSOLUTE_TIMEOUT.ago..) }

  def self.digest(token)
    OpenSSL::Digest::SHA256.hexdigest(token)
  end

  def self.find_by_token(token)
    return if token.blank?

    active.find_by(token_digest: digest(token))
  end

  def touch_activity!
    update_column(:last_active_at, Time.current) if last_active_at < ACTIVITY_UPDATE_INTERVAL.ago
  end

  # Signed in within the last few minutes: required before adding a first password.
  def recently_authenticated?
    created_at > RECENT_AUTHENTICATION.ago
  end

  private
    def generate_token
      @token = SecureRandom.base58(32)
      self.token_digest = self.class.digest(@token)
      self.last_active_at ||= Time.current
    end
end
