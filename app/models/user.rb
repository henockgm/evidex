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
  has_many :recovery_codes, dependent: :delete_all
  has_many :known_devices, dependent: :delete_all
  has_many :job_postings, dependent: :destroy
  has_many :documents, dependent: :destroy
  has_many :document_chunks, dependent: :delete_all

  # For the admin users list: session and AI usage figures per user, in one query.
  # Last activity also counts sign-ins, so it survives sign-outs and admin locks.
  scope :with_admin_stats, -> {
    select("users.*",
      sanitize_sql_array([ <<~SQL.squish, { idle: Session::IDLE_TIMEOUT.ago, absolute: Session::ABSOLUTE_TIMEOUT.ago, ai_since: 30.days.ago } ]))
        (SELECT COUNT(*) FROM sessions s WHERE s.user_id = users.id
          AND s.last_active_at >= :idle AND s.created_at >= :absolute) AS active_sessions_count,
        GREATEST(
          (SELECT MAX(s.last_active_at) FROM sessions s WHERE s.user_id = users.id),
          (SELECT MAX(e.created_at) FROM audit_events e WHERE e.user_id = users.id AND e.action IN ('signed_in', 'oauth_signed_in'))
        ) AS last_active_at,
        (SELECT COUNT(*) FROM ai_usages a WHERE a.user_id = users.id AND a.created_at >= :ai_since) AS ai_calls_last_30_days
      SQL
  }

  normalizes :email_address, with: ->(email) { email.strip.downcase }

  encrypts :otp_secret

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

  OTP_ISSUER = "Evidex"

  def two_factor_enabled?
    otp_enabled_at.present?
  end

  def totp(secret = otp_secret)
    ROTP::TOTP.new(secret, issuer: OTP_ISSUER)
  end

  # True for a current code that hasn't been used before; remembers its time
  # step so the same code can't be replayed.
  def verify_otp!(code, secret: otp_secret)
    return false if secret.blank? || code.to_s.gsub(/\s/, "") !~ /\A\d{6}\z/

    accepted_at = totp(secret).verify(code.to_s.gsub(/\s/, ""), drift_behind: 30, drift_ahead: 30,
      after: otp_last_timestep && Time.at(otp_last_timestep * 30))
    return false unless accepted_at

    update_columns(otp_last_timestep: accepted_at / 30, updated_at: Time.current)
    true
  end

  # Accepts an authenticator code or an unused recovery code.
  def verify_second_factor!(code)
    return false unless two_factor_enabled?

    verify_otp!(code) || RecoveryCode.consume!(self, code)
  end

  def enable_two_factor!(secret)
    transaction do
      update!(otp_secret: secret, otp_enabled_at: Time.current)
      RecoveryCode.regenerate_for!(self)
    end
  end

  def disable_two_factor!
    transaction do
      update!(otp_secret: nil, otp_enabled_at: nil, otp_last_timestep: nil)
      recovery_codes.delete_all
    end
  end

  # Locked out of password and two-factor sign-in: temporarily after failed
  # attempts, or until an admin unlocks the account.
  def locked?
    suspended? || temporarily_locked?
  end

  def temporarily_locked?
    locked_until.present? && locked_until.future?
  end

  def suspended?
    suspended_at.present?
  end

  # Admin lock: blocks every sign-in and ends every session.
  def suspend!
    transaction do
      update!(suspended_at: Time.current)
      sessions.delete_all
    end
  end

  # Lifts the admin lock and any temporary lock after failed sign-ins.
  def unsuspend!
    update!(suspended_at: nil)
    reset_failed_sign_ins!
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
