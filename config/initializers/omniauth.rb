# Google and Microsoft sign-in. A provider is enabled only when its credentials
# are configured, and the SPA asks GET /api/v1/auth/providers which buttons to show.
#
# OmniAuth request phase is POST-only with a Rails CSRF token
# (omniauth-rails_csrf_protection), which prevents login CSRF.
module Evidex
  # reauthenticate: query for confirming it's the user before a sensitive change.
  # Microsoft can be asked to show its sign-in form again; Google can only be
  # asked to show its account chooser (already the default).
  OAUTH_PROVIDERS = {
    google_oauth2: { label: "Google", env: %w[GOOGLE_CLIENT_ID GOOGLE_CLIENT_SECRET], reauthenticate: { intent: "reauthenticate" } },
    entra_id: { label: "Microsoft", env: %w[MICROSOFT_CLIENT_ID MICROSOFT_CLIENT_SECRET], reauthenticate: { intent: "reauthenticate", prompt: "login" } }
  }.freeze

  def self.enabled_oauth_providers
    OAUTH_PROVIDERS.select { |_, provider| provider[:env].all? { |key| ENV[key].present? } }.keys
  end
end

if Rails.env.test?
  # Register both providers in tests; OmniAuth test mode stubs the provider side.
  Evidex::OAUTH_PROVIDERS.each_value { |provider| provider[:env].each { |key| ENV[key] ||= "test-#{key.downcase}" } }
end

Rails.application.config.middleware.use OmniAuth::Builder do
  enabled = Evidex.enabled_oauth_providers

  if enabled.include?(:google_oauth2)
    provider :google_oauth2, ENV["GOOGLE_CLIENT_ID"], ENV["GOOGLE_CLIENT_SECRET"],
      scope: "openid,email,profile", prompt: "select_account"
  end

  if enabled.include?(:entra_id)
    # "common" accepts both personal Microsoft accounts and work/school accounts.
    provider :entra_id,
      client_id: ENV["MICROSOFT_CLIENT_ID"],
      client_secret: ENV["MICROSOFT_CLIENT_SECRET"],
      tenant_id: ENV.fetch("MICROSOFT_TENANT_ID", "common")
  end
end

OmniAuth.config.logger = Rails.logger
OmniAuth.config.on_failure = proc { |env| OmniauthCallbacksController.action(:failure).call(env) }
