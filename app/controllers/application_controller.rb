class ApplicationController < ActionController::API
  include ActionController::Cookies
  include ActionController::RequestForgeryProtection
  include ProblemDetails

  # The SPA sends the token from GET /api/v1/csrf_token in the X-CSRF-Token header.
  protect_from_forgery with: :exception
  # API controllers don't pick up config.action_controller.allow_forgery_protection
  # (it's set before this module is included), so apply it here. Only test turns it off.
  self.allow_forgery_protection = Rails.configuration.action_controller.allow_forgery_protection != false
end
