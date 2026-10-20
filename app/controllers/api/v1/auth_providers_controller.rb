module Api
  module V1
    class AuthProvidersController < BaseController
      allow_unauthenticated_access

      def index
        providers = Evidex.enabled_oauth_providers.map do |id|
          { id: id.to_s, label: Evidex::OAUTH_PROVIDERS.dig(id, :label), path: "/auth/#{id}" }
        end
        render json: { providers: }
      end
    end
  end
end
