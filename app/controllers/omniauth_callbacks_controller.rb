# Google/Microsoft redirect here after the user consents. Responses are browser
# redirects back into the SPA, never JSON.
class OmniauthCallbacksController < ApplicationController
  include Authentication

  allow_unauthenticated_access
  # Providers may POST the callback; OmniAuth's state parameter protects it instead.
  skip_forgery_protection

  def create
    resume_session
    return reauthenticate if Current.user && request.env["omniauth.params"]&.dig("intent") == "reauthenticate"

    # The shared demo account can't have sign-in methods linked to it.
    return redirect_to("/") if Current.user&.demo?

    linking = Current.user.present?
    result = OauthSignIn.new(auth: request.env["omniauth.auth"], current_user: Current.user).call

    unless result.success?
      return redirect_to(linking ? "/settings/security?error=#{result.error}" : "/login?error=#{result.error}")
    end

    user = result.user
    return redirect_to("/login?error=account_suspended") if user.suspended?

    record_outcome(user, result.outcome)

    if linking
      redirect_to "/settings/security?linked=#{provider}"
    elsif user.two_factor_enabled?
      begin_second_factor_for(user, method: provider)
      redirect_to "/login/verify"
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
    # Sudo mode for accounts that only sign in with Google/Microsoft: signing in
    # again with a provider account already connected to this user. Accounts with
    # a password or two-factor sign-in confirm with those instead.
    def reauthenticate
      auth = request.env["omniauth.auth"]
      user = Current.user
      if !user.password? && !user.two_factor_enabled? && user.identities.exists?(provider: auth.provider, uid: auth.uid)
        Current.session.reauthenticate!
        AuditEvent.record(:reauthenticated, user:, request:, provider:)
        redirect_to "/settings/security?reauthenticated=1"
      else
        AuditEvent.record(:reauthentication_failed, user:, request:, provider:)
        redirect_to "/settings/security?error=reauthentication_failed"
      end
    end

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
      AuditEvent.record(:oauth_signed_in, user:, request:, provider:) unless Current.user || user.two_factor_enabled?
    end
end
