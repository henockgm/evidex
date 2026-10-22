module Authentication
  extend ActiveSupport::Concern

  SESSION_COOKIE = :"#{Rails.configuration.x.cookie_prefix}evidex_session"
  DEVICE_COOKIE = :"#{Rails.configuration.x.cookie_prefix}evidex_device"

  included do
    before_action :require_authentication
  end

  # Problem type the SPA watches for to ask the user to confirm it's them.
  REAUTHENTICATION_REQUIRED = "urn:evidex:problem:reauthentication-required".freeze

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end

    # Sensitive changes need a sign-in or re-authentication from the last few minutes.
    def require_recent_authentication(**options)
      before_action :require_recent_authentication, **options
    end
  end

  private
    def authenticated?
      resume_session.present?
    end

    def require_authentication
      return if authenticated?

      render_problem :unauthorized, "Authentication required"
    end

    def require_recent_authentication
      return if Current.session&.recently_authenticated?

      render_problem :forbidden, "Confirm it's you", type: REAUTHENTICATION_REQUIRED,
        detail: "For your security, confirm your identity before making this change."
    end

    def resume_session
      Current.session ||= Session.find_by_token(cookies.signed[SESSION_COOKIE])&.tap(&:touch_activity!)
    end

    def start_new_session_for(user)
      # A fresh Rails session (and CSRF token) on every sign-in prevents session fixation.
      reset_session

      user.sessions.create!(user_agent: request.user_agent&.first(255), ip_address: request.remote_ip).tap do |session|
        Current.session = session
        cookies.signed[SESSION_COOKIE] = {
          value: session.token,
          expires: Session::ABSOLUTE_TIMEOUT.from_now,
          httponly: true,
          secure: Rails.env.production?,
          same_site: :lax
        }
        notify_if_new_device(user)
      end
    end

    # A random token per browser that outlives sign-outs, so a sign-in from a
    # browser the user hasn't used before can be emailed to them.
    def notify_if_new_device(user)
      token = cookies.signed[DEVICE_COOKIE].presence || SecureRandom.base58(32)
      cookies.signed[DEVICE_COOKIE] = { value: token, expires: 2.years.from_now, httponly: true, secure: Rails.env.production?, same_site: :lax }
      return unless KnownDevice.new_for?(user, token, request)

      UserMailer.with(user:, user_agent: request.user_agent, ip_address: request.remote_ip, at: Time.current).new_device_sign_in.deliver_later
    end

    SECOND_FACTOR_WINDOW = 5.minutes

    # After the first factor (password or Google/Microsoft) for a user with 2FA:
    # remember who is half-way signed in, in the encrypted Rails session.
    def begin_second_factor_for(user, method:)
      reset_session
      session[:pending_second_factor] = {
        "user_id" => user.id, "method" => method, "attempts" => 0,
        "expires_at" => SECOND_FACTOR_WINDOW.from_now.to_i
      }
    end

    def pending_second_factor
      pending = session[:pending_second_factor]
      pending if pending.is_a?(Hash) && pending["expires_at"].to_i > Time.current.to_i
    end

    def terminate_session
      Current.session&.destroy
      Current.session = nil
      cookies.delete(SESSION_COOKIE)
      reset_session
    end
end
