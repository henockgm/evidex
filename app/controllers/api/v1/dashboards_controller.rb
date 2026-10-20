module Api
  module V1
    class DashboardsController < BaseController
      def show
        render json: DashboardQuery.new(Current.user).call
      end
    end
  end
end
