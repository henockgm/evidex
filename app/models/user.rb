class User < ApplicationRecord
  PASSWORD_MIN_LENGTH = 12
  PASSWORD_MAX_BYTES = 72 # bcrypt ignores anything longer
  MAX_FAILED_SIGN_INS = 5
  BASE_LOCKOUT = 15.minutes
  MAX_LOCKOUT = 24.hours

  # Validations are declared below so that OAuth-only accounts can exist without a password.
  # reset_token: adds password_reset_token / find_by_password_reset_token (15 min, single use).
  has_secure_password validations: false, reset_token: true

  has_many :sessions, dependent: :delete_all
  has_many :identities, dependent: :delete_all
  has_many :audit_events, dependent: :delete_all

  normalizes :email_address, with: ->(email) { email.strip.downcase }

  validates :email_address, presence: true, uniqueness: true, length: { maximum: 254 },
    format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :name, length: { maximum: 100 }

  # :registration and :password_change are the contexts in which a password is mandatory.
  validates :password, presence: true, on: %i[registration password_change]
  validates :password, length: { minimum: PASSWORD_MIN_LENGTH }, allow_blank: true
  validate :password_within_bcrypt_limit
  validate :password_not_breached

  # Valid until used: verifying changes email_verified_at, which invalidates the token.
  generates_token_for :email_verification, expires_in: 24.hours do
    "#{email_address}|#{email_verified_at&.iso8601}"
  end

  def verified?
    email_verified_at.present?
  end

  def verify_email!
    update!(email_verified_at: Time.current) unless verified?
  end

  def password?
    password_digest.present?
  end

  def sign_in_methods_count
    identities.count + (password? ? 1 : 0)
  end

  def locked?
    locked_until.present? && locked_until.future?
  end

  # Returns true when this failure locked the account. Each consecutive lockout
  # doubles in length, up to MAX_LOCKOUT.
  def register_failed_sign_in!
    with_lock do
      count = failed_sign_in_count + 1

      if count >= MAX_FAILED_SIGN_INS
        duration = [ BASE_LOCKOUT * (2**lockout_count), MAX_LOCKOUT ].min
        update_columns(failed_sign_in_count: 0, lockout_count: lockout_count + 1,
          locked_until: duration.from_now, updated_at: Time.current)
        true
      else
        update_columns(failed_sign_in_count: count, updated_at: Time.current)
        false
      end
    end
  end

  def reset_failed_sign_ins!
    return if failed_sign_in_count.zero? && lockout_count.zero? && locked_until.nil?

    update_columns(failed_sign_in_count: 0, lockout_count: 0, locked_until: nil, updated_at: Time.current)
  end

  private
    def password_within_bcrypt_limit
      return if password.blank? || password.bytesize <= PASSWORD_MAX_BYTES

      errors.add(:password, :too_long, count: PASSWORD_MAX_BYTES)
    end

    def password_not_breached
      return unless Rails.configuration.x.pwned_passwords_check
      return if password.blank? || errors.include?(:password)

      errors.add(:password, "has appeared in a known data breach; choose a different one") if PwnedPasswords.breached?(password)
    end
end
