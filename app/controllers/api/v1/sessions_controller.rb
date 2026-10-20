module Api
  module V1
    # Password sign-in and sign-out.
    class SessionsController < BaseController
      FAILURE = "Invalid email or password, or the account is temporarily locked.".freeze

      allow_unauthenticated_access only: :create
      limit_requests to: 10, within: 3.minutes, only: :create

      def create
        email = normalized_email_param
        # authenticate_by takes the same time whether or not the email exists.
        user = User.authenticate_by(email_address: email, password: params[:password].to_s)

        if user && !user.locked?
          user.reset_failed_sign_ins!
          start_new_session_for(user)
          AuditEvent.record(:signed_in, user:, request:, method: "password")
          render json: { user: UserSerializer.new(user) }, status: :created
        else
          record_failure(user || User.find_by(email_address: email))
          render_problem :unauthorized, FAILURE
        end
      end

      def destroy
        AuditEvent.record(:signed_out, user: Current.user, request:)
        terminate_session
        head :no_content
      end

      private
        def record_failure(user)
          AuditEvent.record(:sign_in_failed, user:, request:)
          return if user.nil? || user.locked?

          if user.register_failed_sign_in!
            AuditEvent.record(:account_locked, user:, request:, until: user.locked_until.iso8601)
            UserMailer.with(user:).account_locked.deliver_later
          end
        end
    end
  end
end
