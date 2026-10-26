module Api
  module V1
    module Me
      # "Sudo mode": the signed-in user proves it's them again before a sensitive
      # change. It asks for the same factors as signing in: the password, plus a
      # code when two-factor sign-in is on. Accounts without a password confirm
      # with a code, or by signing in with Google/Microsoft again.
      class ReauthenticationsController < BaseController
        locked_in_demo

        limit_requests to: 5, within: 15.minutes, by: -> { Current.user&.id || request.remote_ip }

        def create
          user = Current.user
          unless user.password? || user.two_factor_enabled?
            return render_problem(:unprocessable_content, "Confirm with your connected account",
              detail: "Sign in with Google or Microsoft again (POST to the provider's reauthenticate_path) to confirm it's you.")
          end

          errors = {}
          errors[:password] = [ "Password is incorrect" ] if user.password? && !user.authenticate(params[:password].to_s)
          errors[:code] = [ "Code is incorrect or expired" ] if errors.empty? && user.two_factor_enabled? && !user.verify_second_factor!(params[:code].to_s)

          if errors.any?
            AuditEvent.record(:reauthentication_failed, user:, request:, fields: errors.keys)
            return render_problem(:unprocessable_content, "Validation failed", errors:)
          end

          Current.session.reauthenticate!
          AuditEvent.record(:reauthenticated, user:, request:)
          render json: { recently_authenticated_until: Current.session.recently_authenticated_until.iso8601 }, status: :created
        end
      end
    end
  end
end
