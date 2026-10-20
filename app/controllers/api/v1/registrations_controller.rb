module Api
  module V1
    # Responds the same way whether or not the email is already registered, so the
    # endpoint can't be used to find out who has an account. The existing owner
    # gets an email instead.
    class RegistrationsController < BaseController
      MESSAGE = "Check your inbox to confirm your email address. You can sign in now.".freeze

      allow_unauthenticated_access
      limit_requests to: 5, within: 1.hour, only: :create

      def create
        email = normalized_email_param

        if (existing = User.find_by(email_address: email))
          UserMailer.with(user: existing).registration_attempt.deliver_later
          AuditEvent.record(:registration_duplicate, user: existing, request:)
          return render_accepted(MESSAGE)
        end

        user = User.new(email_address: email, name: params[:name], password: params[:password])
        if user.save(context: :registration)
          UserMailer.with(user:).email_verification.deliver_later
          AuditEvent.record(:registered, user:, request:)
          render_accepted(MESSAGE)
        else
          render_validation_errors(user)
        end
      rescue ActiveRecord::RecordNotUnique
        render_accepted(MESSAGE)
      end
    end
  end
end
