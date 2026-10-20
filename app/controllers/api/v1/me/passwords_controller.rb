module Api
  module V1
    module Me
      # Changes the password, or adds a first one to an account that only uses
      # Google/Microsoft. Signs out every other device.
      class PasswordsController < BaseController
        limit_requests to: 5, within: 15.minutes, by: -> { Current.user&.id || request.remote_ip }

        def update
          user = Current.user

          if user.password?
            unless user.authenticate(params[:current_password].to_s)
              return render_problem(:unprocessable_content, "Validation failed", errors: { current_password: [ "Current password is incorrect" ] })
            end
          elsif !Current.session.recently_authenticated?
            return render_problem(:forbidden, "Recent sign-in required", detail: "Sign out and sign in again, then add a password.")
          end

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
