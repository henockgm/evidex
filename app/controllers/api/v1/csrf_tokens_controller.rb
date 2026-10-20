module Api
  module V1
    class CsrfTokensController < BaseController
      allow_unauthenticated_access

      def show
        render json: { csrf_token: form_authenticity_token }
      end
    end
  end
end
