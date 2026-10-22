module Api
  module V1
    class AuthProvidersController < BaseController
      allow_unauthenticated_access

      def index
        providers = Evidex.enabled_oauth_providers.map do |id|
          provider = Evidex::OAUTH_PROVIDERS.fetch(id)
          { id: id.to_s, label: provider[:label], path: "/auth/#{id}",
            reauthenticate_path: "/auth/#{id}?#{provider[:reauthenticate].to_query}" }
        end
        render json: { providers: }
      end
    end
  end
end
