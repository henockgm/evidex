module Api
  module V1
    class BaseController < ApplicationController
      include Authentication

      def self.limit_requests(to:, within:, **options)
        rate_limit to:, within:, store: Rails.configuration.x.rate_limit_store || Rails.cache,
          with: -> { render_problem :too_many_requests, "Too many requests", detail: "Please wait a few minutes and try again." },
          **options
      end

      private
        def normalized_email_param
          User.normalize_value_for(:email_address, params.require(:email_address).to_s)
        end

        def render_accepted(message)
          render json: { message: }, status: :accepted
        end
    end
  end
end
