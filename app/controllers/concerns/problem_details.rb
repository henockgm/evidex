# Errors are rendered as RFC 9457 problem details:
#   { "type": "about:blank", "title": "...", "status": 422, "detail": "...", "errors": { "field": ["..."] } }
module ProblemDetails
  extend ActiveSupport::Concern

  included do
    rescue_from ActiveRecord::RecordNotFound do
      render_problem :not_found, "Not found"
    end

    rescue_from ActionController::ParameterMissing do |error|
      render_problem :bad_request, "Missing parameter", detail: error.message
    end

    rescue_from ActionController::InvalidAuthenticityToken do
      render_problem :forbidden, "Invalid CSRF token",
        detail: "Fetch a token from GET /api/v1/csrf_token and send it in the X-CSRF-Token header."
    end
  end

  private
    def render_problem(status, title, detail: nil, errors: nil, type: "about:blank")
      code = Rack::Utils.status_code(status)
      body = { type:, title:, status: code, detail:, errors: }.compact
      render json: body, status: code, content_type: "application/problem+json"
    end

    def render_validation_errors(record)
      render_problem :unprocessable_content, "Validation failed",
        errors: record.errors.to_hash(true)
    end
end
