module Api
  module V1
    class StatusesController < BaseController
      allow_unauthenticated_access

      def show
        render json: {
          name: "Evidex",
          api_version: "v1",
          environment: Rails.env,
          database: database_status,
          time: Time.current.iso8601
        }
      end

      private
        def database_status
          ActiveRecord::Base.connection.select_value("SELECT 1") == 1 ? "ok" : "error"
        rescue ActiveRecord::ActiveRecordError
          "error"
        end
    end
  end
end
