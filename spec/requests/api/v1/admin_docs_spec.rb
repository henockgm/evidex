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

  path "/api/v1/admin/users" do
    get "List accounts (admins only)" do
      tags "Admin"
      produces "application/json"
      security [ { session_cookie: [] } ]
      description "Account metadata only, newest first, 25 per page. Never documents, postings, reports or letters."
      parameter name: :q, in: :query, required: false, schema: { type: :string }, description: "Part of an email address or name"
      parameter name: :page, in: :query, required: false, schema: { type: :integer, minimum: 1 }

      response "200", "accounts" do
        schema type: :object, required: %w[users meta],
          properties: {
            users: { type: :array, items: { "$ref" => "#/components/schemas/AdminUser" } },
            meta: { "$ref" => "#/components/schemas/PageMeta" }
          }
        let(:q) { nil }
        let(:page) { nil }
        run_test!
      end
    end
  end
end
