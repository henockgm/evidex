module Evidex
  # Security headers for every response, set outermost in the middleware stack so
  # they also cover static files (the built SPA) and error pages.
  #
  # The SPA is built without inline scripts or styles, so its policy allows only
  # its own origin. Two exceptions: the Swagger UI and the development mail
  # preview use inline code, and in development the policy is report-only so
  # Rails' own error pages keep working.
  class SecurityHeaders
    # Google/Microsoft sign-in starts with a form POST that redirects to the
    # provider, and browsers check form-action along that redirect.
    OAUTH_FORM_TARGETS = %w[https://accounts.google.com https://login.microsoftonline.com https://login.live.com].freeze

    APP_POLICY = {
      "default-src" => "'self'",
      "script-src" => "'self'",
      "style-src" => "'self'",
      "img-src" => "'self' data:",
      "font-src" => "'self'",
      "connect-src" => "'self'",
      "object-src" => "'none'",
      "base-uri" => "'none'",
      "frame-ancestors" => "'none'",
      "form-action" => [ "'self'", *OAUTH_FORM_TARGETS ].join(" ")
    }.freeze

    INLINE_TOOL_POLICY = APP_POLICY.merge(
      "script-src" => "'self' 'unsafe-inline'",
      "style-src" => "'self' 'unsafe-inline'",
      "form-action" => "'self'"
    ).freeze
    INLINE_TOOL_PATHS = %w[/api-docs /letter_opener].freeze

    HEADERS = {
      "x-content-type-options" => "nosniff",
      "x-frame-options" => "DENY",
      "referrer-policy" => "same-origin",
      "permissions-policy" => "camera=(), microphone=(), geolocation=(), payment=(), usb=(), browsing-topics=()",
      "cross-origin-opener-policy" => "same-origin",
      "cross-origin-resource-policy" => "same-origin",
      "x-permitted-cross-domain-policies" => "none"
    }.freeze

    def initialize(app, report_only: false, upgrade_insecure_requests: false)
      @app = app
      @policy_header = report_only ? "content-security-policy-report-only" : "content-security-policy"
      @upgrade = upgrade_insecure_requests
    end

    def call(env)
      # Read the path first: routing rewrites PATH_INFO for mounted engines.
      path = env["PATH_INFO"].to_s
      status, headers, body = @app.call(env)

      HEADERS.each { |name, value| headers[name] = value }
      headers[@policy_header] = policy_for(path)
      # Account data (recovery codes included) must never sit in a browser or proxy cache.
      headers["cache-control"] = "no-store" if path.start_with?("/api/")
      [ status, headers, body ]
    end

    private
      def policy_for(path)
        policy = INLINE_TOOL_PATHS.any? { |prefix| path.start_with?(prefix) } ? INLINE_TOOL_POLICY : APP_POLICY
        directives = policy.map { |name, value| "#{name} #{value}" }
        directives << "upgrade-insecure-requests" if @upgrade
        directives.join("; ")
      end
  end
end
