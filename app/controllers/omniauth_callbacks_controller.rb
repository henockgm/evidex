# Google/Microsoft redirect here after the user consents. Responses are browser
# redirects back into the SPA, never JSON.
class OmniauthCallbacksController < ApplicationController
  include Authentication

  allow_unauthenticated_access
  # Providers may POST the callback; OmniAuth's state parameter protects it instead.
  skip_forgery_protection

  def create
    resume_session
    linking = Current.user.present?
    result = OauthSignIn.new(auth: request.env["omniauth.auth"], current_user: Current.user).call

    unless result.success?
      return redirect_to(linking ? "/settings/security?error=#{result.error}" : "/login?error=#{result.error}")
    end

    user = result.user
    record_outcome(user, result.outcome)

    if linking
      redirect_to "/settings/security?linked=#{provider}"
    else
      start_new_session_for(user)
      redirect_to "/"
    end
  end

  def failure
    path = authenticated? ? "/settings/security" : "/login"
    redirect_to "#{path}?error=oauth_failed"
  end

  private
    def provider
      request.env["omniauth.auth"].provider
    end

    def record_outcome(user, outcome)
      case outcome
      when :registered
        AuditEvent.record(:registered, user:, request:, provider:)
        UserMailer.with(user:).email_verification.deliver_later unless user.verified?
      when :linked
        AuditEvent.record(:identity_linked, user:, request:, provider:)
        UserMailer.with(user:, provider:).identity_linked.deliver_later
      end
      AuditEvent.record(:oauth_signed_in, user:, request:, provider:) unless Current.user
    end
end
