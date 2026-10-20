module Api
  module V1
    class MeController < BaseController
      def show
        render json: { user: UserSerializer.new(Current.user) }
      end

      # Deletes the account and everything it owns. Requires the password, or for
      # accounts without one, the email address typed out as confirmation.
      def destroy
        user = Current.user
        confirmed = user.password? ? user.authenticate(params[:password].to_s) : params[:confirm_email].to_s.strip.casecmp?(user.email_address)
        return render_problem(:unprocessable_content, "Confirmation failed",
          detail: user.password? ? "Password is incorrect." : "Type your email address to confirm.") unless confirmed

        terminate_session
        user.destroy!
        head :no_content
      end
    end
  end
end
