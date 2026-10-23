module Api
  module V1
    module Admin
      # Headline numbers for the instance.
      class OverviewsController < BaseController
        def show
          render json: {
            users: User.count,
            verified_users: User.where.not(email_verified_at: nil).count,
            two_factor_users: User.where.not(otp_enabled_at: nil).count,
            active_sessions: Session.active.count,
            ai_calls_last_30_days: AiUsage.where(created_at: 30.days.ago..).count
          }
        end
      end
    end
  end
end
