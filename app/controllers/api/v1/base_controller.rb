module Api
  module V1
    class BaseController < ApplicationController
      include Authentication

      # Problem type for what the shared demo account can't do (Demo::Account).
      DEMO_LOCKED = "urn:evidex:problem:demo-locked".freeze

      # Account settings and uploads are personal, and the demo is shared by every visitor.
      def self.locked_in_demo(**options)
        before_action :reject_demo_account, **options
      end

      def self.limit_requests(to:, within:, **options)
        rate_limit to:, within:, store: Rails.configuration.x.rate_limit_store || Rails.cache,
          with: -> { render_problem :too_many_requests, "Too many requests", detail: "Please wait a few minutes and try again." },
          **options
      end

      private
        def reject_demo_account
          return unless Current.user&.demo?

          render_problem :forbidden, "Not available in the demo", type: DEMO_LOCKED,
            detail: "The demo account is shared by all visitors. Create your own account to use this."
        end

        def normalized_email_param
          User.normalize_value_for(:email_address, params.require(:email_address).to_s)
        end

        def render_accepted(message)
          render json: { message: }, status: :accepted
        end
    end
  end
end
