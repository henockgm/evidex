module Api
  module V1
    class MeController < BaseController
      require_recent_authentication only: :destroy

      def show
        render json: { user: UserSerializer.new(Current.user) }
      end

      # Deletes the account and everything it owns. Needs a recent sign-in, and the
      # email address typed out so it can't happen by accident.
      def destroy
        user = Current.user
        unless params[:confirm_email].to_s.strip.casecmp?(user.email_address)
          return render_problem(:unprocessable_content, "Validation failed",
            errors: { confirm_email: [ "Type your email address to confirm" ] })
        end

        terminate_session
        user.destroy!
        head :no_content
      end
    end
  end
end
