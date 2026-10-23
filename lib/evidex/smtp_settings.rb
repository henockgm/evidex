module Evidex
  # Action Mailer SMTP settings from environment variables, for production
  # (Brevo's SMTP relay, see the deployment notes). Port 587 starts plain and
  # upgrades with STARTTLS; the connection fails rather than send unencrypted.
  module SmtpSettings
    REQUIRED = %w[SMTP_ADDRESS SMTP_USERNAME SMTP_PASSWORD].freeze

    # nil when SMTP_ADDRESS isn't set (e.g. running the image locally), so the
    # caller can leave mail delivery as it is.
    def self.from(env)
      return if env["SMTP_ADDRESS"].blank?

      missing = REQUIRED.select { |name| env[name].blank? }
      raise KeyError, "SMTP is configured but missing #{missing.join(', ')}" if missing.any?

      {
        address: env["SMTP_ADDRESS"],
        port: Integer(env.fetch("SMTP_PORT", "587")),
        user_name: env["SMTP_USERNAME"],
        password: env["SMTP_PASSWORD"],
        authentication: :login,
        enable_starttls: true,
        open_timeout: 10,
        read_timeout: 10
      }
    end
  end
end
