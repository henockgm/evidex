# Keys for Active Record encryption (used for the 2FA secret).
#
# Production reads them from the environment and refuses to start without them;
# generate a set with `bin/rails db:encryption:init`. Development and test use
# fixed keys that are public in this repository, so anyone can run the app
# locally. They protect nothing and must never be used in production.
keys = {
  primary_key: ENV["ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY"],
  deterministic_key: ENV["ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY"],
  key_derivation_salt: ENV["ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT"]
}

if keys.values.any?(&:blank?)
  if Rails.env.production?
    raise "Set ACTIVE_RECORD_ENCRYPTION_PRIMARY_KEY, ACTIVE_RECORD_ENCRYPTION_DETERMINISTIC_KEY " \
      "and ACTIVE_RECORD_ENCRYPTION_KEY_DERIVATION_SALT (see bin/rails db:encryption:init)"
  end

  keys = {
    primary_key: "evidex-development-only-primary-key-not-secret",
    deterministic_key: "evidex-development-only-deterministic-key-not-secret",
    key_derivation_salt: "evidex-development-only-salt-not-secret"
  }
end

Rails.application.config.active_record.encryption.primary_key = keys[:primary_key]
Rails.application.config.active_record.encryption.deterministic_key = keys[:deterministic_key]
Rails.application.config.active_record.encryption.key_derivation_salt = keys[:key_derivation_salt]
