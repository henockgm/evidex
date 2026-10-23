require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
# require "action_mailbox/engine"
# require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module Evidex
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.1

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    config.api_only = true

    # Uploaded files are only served through authenticated API endpoints,
    # never through Active Storage's public (signed URL) routes.
    config.active_storage.draw_routes = false

    # The SPA and API share one origin and authenticate with cookies, so the
    # API-only stack needs cookie and session middleware back. The Rails session
    # only carries the CSRF token and OmniAuth state; sign-in sessions live in
    # the database (see Session).
    config.middleware.use ActionDispatch::Cookies
    # In production cookie names get the __Host- prefix: browsers then only accept
    # them over HTTPS, for the whole site, and never from a subdomain.
    config.x.cookie_prefix = Rails.env.production? ? "__Host-" : ""
    config.middleware.use ActionDispatch::Session::CookieStore,
      key: "#{config.x.cookie_prefix}evidex_state", same_site: :lax, secure: Rails.env.production?, httponly: true

    # Public URL of the SPA, used in email links and OAuth redirects.
    config.x.app_url = ENV.fetch("APP_URL", "http://localhost:5173")
    # The built React app (npm run build in frontend/), served by Rails in production.
    config.x.spa_root = Rails.root.join(ENV.fetch("EVIDEX_SPA_ROOT", "frontend/dist"))

    # Reject passwords found in known breaches (Have I Been Pwned range API).
    config.x.pwned_passwords_check = ENV.fetch("PWNED_PASSWORDS_CHECK", "true") == "true"

    # Store used by controller rate limits (Rails.cache unless overridden).
    config.x.rate_limit_store = nil
  end
end
