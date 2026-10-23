module Api
  module V1
    module Admin
      # The admin area. Non-admins get 404, so it doesn't reveal that it exists.
      # Admins must have two-factor sign-in on: a leaked password (or Google
      # account) alone can't operate the instance.
      #
      # Admin endpoints return account metadata only, never users' documents,
      # postings, reports or letters (ADM-03).
      class BaseController < Api::V1::BaseController
        TWO_FACTOR_REQUIRED = "urn:evidex:problem:two-factor-required".freeze

        before_action :require_admin

        private
          def require_admin
            return render_problem(:not_found, "Not found") unless Current.user.admin?
            return if Current.user.two_factor_enabled?

            render_problem :forbidden, "Two-factor sign-in required", type: TWO_FACTOR_REQUIRED,
              detail: "Turn on two-factor sign-in in your security settings to use the admin area."
          end
      end
    end
  end
end
