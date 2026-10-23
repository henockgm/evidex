module Api
  module V1
    module Admin
      # Lock an account (signs it out everywhere and blocks every sign-in) or
      # unlock it again. Needs a recent sign-in, like other sensitive changes.
      class UserLocksController < BaseController
        require_recent_authentication

        before_action :set_user

        def create
          if @user == Current.user
            return render_problem(:unprocessable_content, "You can't lock your own account")
          end

          unless @user.suspended?
            @user.suspend!
            AuditEvent.record(:admin_locked, user: @user, request:, admin_id: Current.user.id)
            UserMailer.with(user: @user).account_suspended.deliver_later
          end
          render json: { user: AdminUserSerializer.new(User.with_admin_stats.find(@user.id)) }
        end

        def destroy
          if @user.locked?
            @user.unsuspend!
            AuditEvent.record(:admin_unlocked, user: @user, request:, admin_id: Current.user.id)
          end
          render json: { user: AdminUserSerializer.new(User.with_admin_stats.find(@user.id)) }
        end

        private
          def set_user
            @user = User.find(params[:user_id])
          end
      end
    end
  end
end
