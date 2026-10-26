module Api
  module V1
    module Me
      # Changes the password, or adds a first one to an account that only uses
      # Google/Microsoft. Needs a recent sign-in. Signs out every other device.
      class PasswordsController < BaseController
        locked_in_demo

        limit_requests to: 5, within: 15.minutes, by: -> { Current.user&.id || request.remote_ip }
        require_recent_authentication

        def update
          user = Current.user
          user.password = params[:password]
          return render_validation_errors(user) unless user.save(context: :password_change)

          user.sessions.where.not(id: Current.session.id).delete_all
          AuditEvent.record(:password_changed, user:, request:)
          UserMailer.with(user:).password_changed.deliver_later
          render json: { user: UserSerializer.new(user) }
        end
      end
    end
  end
end
