require "evidex/security_headers"

Rails.application.config.middleware.insert_before 0, Evidex::SecurityHeaders,
  report_only: Rails.env.development?,
  upgrade_insecure_requests: Rails.env.production? && Rails.application.config.force_ssl
