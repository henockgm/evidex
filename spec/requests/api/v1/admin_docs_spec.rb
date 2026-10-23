require "swagger_helper"

RSpec.describe "Admin API", type: :request do
  let(:admin) { create(:user, :admin) }

  before { sign_in(admin) }

  path "/api/v1/admin/overview" do
    get "Instance overview (admins only)" do
      tags "Admin"
      produces "application/json"
      security [ { session_cookie: [] } ]
      description "Admin endpoints answer 404 to non-admins, and 403 with type urn:evidex:problem:two-factor-required to admins without two-factor sign-in."

      response "200", "headline numbers" do
        schema type: :object,
          required: %w[users verified_users two_factor_users active_sessions ai_calls_last_30_days],
          properties: {
            users: { type: :integer }, verified_users: { type: :integer }, two_factor_users: { type: :integer },
            active_sessions: { type: :integer }, ai_calls_last_30_days: { type: :integer }
          }
        run_test!
      end

      response "404", "not an admin" do
        schema "$ref" => "#/components/schemas/Problem"
        let(:admin) { create(:user) }
        run_test!
      end
    end
  end
end
