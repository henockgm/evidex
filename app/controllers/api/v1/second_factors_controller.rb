module Api
  module V1
    # The second sign-in step for users with 2FA: an authenticator code or a
    # recovery code, after the password or Google/Microsoft step succeeded.
    class SecondFactorsController < BaseController
      MAX_ATTEMPTS = 5
      FAILURE = "That code didn't work. Check your authenticator app and try again.".freeze

      allow_unauthenticated_access
      limit_requests to: 10, within: 3.minutes

      def create
        pending = pending_second_factor
        user = pending && User.find_by(id: pending["user_id"])
        unless user&.two_factor_enabled?
          session.delete(:pending_second_factor)
          return render_problem(:unauthorized, "Sign-in expired", detail: "Start signing in again.")
        end

        if !user.locked? && user.verify_second_factor!(params.require(:code).to_s)
          used_recovery_code = !params[:code].to_s.gsub(/\s/, "").match?(/\A\d{6}\z/)
          user.reset_failed_sign_ins!
          start_new_session_for(user)
          AuditEvent.record(:signed_in, user:, request:, method: pending["method"],
            second_factor: used_recovery_code ? "recovery_code" : "authenticator")
          UserMailer.with(user:).recovery_code_used.deliver_later if used_recovery_code
          render json: { user: UserSerializer.new(user) }, status: :created
        else
          fail_attempt(user, pending)
        end
      end

      private
        def fail_attempt(user, pending)
          AuditEvent.record(:second_factor_failed, user:, request:)
          locked_now = !user.locked? && user.register_failed_sign_in!
          if locked_now
            AuditEvent.record(:account_locked, user:, request:, until: user.locked_until.iso8601)
            UserMailer.with(user:).account_locked.deliver_later
          end

          attempts = pending["attempts"].to_i + 1
          if attempts >= MAX_ATTEMPTS || user.reload.locked?
            session.delete(:pending_second_factor)
            return render_problem(:unauthorized, "Too many attempts", detail: "Start signing in again.")
          end

          session[:pending_second_factor] = pending.merge("attempts" => attempts)
          render_problem :unprocessable_content, FAILURE
        end
    end
  end
end
