module Authentication
  extend ActiveSupport::Concern

  SESSION_COOKIE = :evidex_session

  included do
    before_action :require_authentication
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
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
      end
    end

    def terminate_session
      Current.session&.destroy
      Current.session = nil
      cookies.delete(SESSION_COOKIE)
      reset_session
    end
end
