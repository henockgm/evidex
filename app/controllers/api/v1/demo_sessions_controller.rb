module Api
  module V1
    # Signs a visitor into the shared demo account (Demo::Account), no password needed.
    # Available once the account exists: bin/rails evidex:demo:reset
    class DemoSessionsController < BaseController
      allow_unauthenticated_access
      limit_requests to: 10, within: 1.hour, by: -> { request.remote_ip }, only: :create

      def show
        render json: { available: Demo::Account.user.present? }
      end

      # Not in the audit log: the demo's activity would show other visitors' addresses.
      def create
        user = Demo::Account.user
        return render_problem(:not_found, "The demo isn't available") unless user

        start_new_session_for(user)
        render json: { user: UserSerializer.new(user) }, status: :created
      end
    end
  end
end
