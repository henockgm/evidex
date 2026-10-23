module Api
  module V1
    module Admin
      # Ends every session of an account, e.g. after a suspected takeover. The
      # user can sign in again straight away.
      class UserSignOutsController < BaseController
        require_recent_authentication

        def create
          user = User.find(params[:user_id])
          if user == Current.user
            return render_problem(:unprocessable_content, "Sign yourself out from your security settings instead")
          end

          count = user.sessions.delete_all
          AuditEvent.record(:admin_signed_out, user:, request:, admin_id: Current.user.id, sessions: count)
          render json: { user: AdminUserSerializer.new(User.with_admin_stats.find(user.id)) }
        end
      end
    end
  end
end
