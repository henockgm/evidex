module Api
  module V1
    module Me
      class IdentitiesController < BaseController
        require_recent_authentication only: :destroy

        def index
          render json: { identities: Current.user.identities.order(:created_at).map { |identity| IdentitySerializer.new(identity) } }
        end

        def destroy
          identity = Current.user.identities.find(params[:id])
          if Current.user.sign_in_methods_count <= 1
            return render_problem(:unprocessable_content, "Can't remove your only sign-in method",
              detail: "Set a password or connect another account first.")
          end

          identity.destroy!
          AuditEvent.record(:identity_unlinked, user: Current.user, request:, provider: identity.provider)
          UserMailer.with(user: Current.user, provider: identity.provider).identity_unlinked.deliver_later
          head :no_content
        end
      end
    end
  end
end
