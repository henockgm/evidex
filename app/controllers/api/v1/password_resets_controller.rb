module Api
  module V1
    class PasswordResetsController < BaseController
      MESSAGE = "If an account exists for that email, a reset link is on its way.".freeze

      allow_unauthenticated_access
      limit_requests to: 5, within: 15.minutes, only: :create
      limit_requests to: 10, within: 15.minutes, only: :update, name: "update"

      def create
        if (user = User.find_by(email_address: normalized_email_param))
          UserMailer.with(user:).password_reset.deliver_later
          AuditEvent.record(:password_reset_requested, user:, request:)
        end
        render_accepted(MESSAGE)
      end

      def update
        user = User.find_by_password_reset_token(params.require(:token).to_s)
        return render_problem(:unprocessable_content, "Invalid or expired link", detail: "Request a new password reset email.") unless user

        user.password = params[:password]
        return render_validation_errors(user) unless user.save(context: :password_change)

        # Following the emailed link proves ownership of the address.
        user.verify_email!
        user.reset_failed_sign_ins!
        user.sessions.delete_all
        AuditEvent.record(:password_reset, user:, request:)
        UserMailer.with(user:).password_changed.deliver_later
        render json: { message: "Your password has been reset. Sign in with your new password." }
      end
    end
  end
end
