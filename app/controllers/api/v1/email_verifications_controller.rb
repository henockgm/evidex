module Api
  module V1
    class EmailVerificationsController < BaseController
      allow_unauthenticated_access only: :create
      limit_requests to: 10, within: 15.minutes, only: :create
      limit_requests to: 3, within: 15.minutes, only: :resend, by: -> { Current.user&.id || request.remote_ip }, name: "resend"

      def create
        user = User.find_by_token_for(:email_verification, params.require(:token))
        return render_problem(:unprocessable_content, "Invalid or expired link", detail: "Request a new confirmation email.") unless user

        user.verify_email!
        AuditEvent.record(:email_verified, user:, request:)
        render json: { message: "Your email address is confirmed." }
      end

      def resend
        return render(json: { message: "Your email address is already confirmed." }) if Current.user.verified?

        UserMailer.with(user: Current.user).email_verification.deliver_later
        render_accepted("A new confirmation email is on its way.")
      end
    end
  end
end
