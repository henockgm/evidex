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

  path "/api/v1/admin/users/{user_id}/lock" do
    parameter name: :user_id, in: :path, schema: { type: :integer }
    let(:target) { create(:user) }
    let(:user_id) { target.id }

    post "Lock an account (admins only)" do
      tags "Admin"
      produces "application/json"
      security [ { session_cookie: [], csrf_token: [] } ]
      description "Signs the account out everywhere, blocks every sign-in until unlocked and emails the user. Needs a recent sign-in (403 urn:evidex:problem:reauthentication-required)."

      response "200", "locked" do
        schema "$ref" => "#/components/schemas/AdminUserEnvelope"
        run_test!
      end

      response "422", "own account" do
        schema "$ref" => "#/components/schemas/Problem"
        let(:user_id) { admin.id }
        run_test!
      end
    end

    delete "Unlock an account (admins only)" do
      tags "Admin"
      produces "application/json"
      security [ { session_cookie: [], csrf_token: [] } ]
      description "Lifts an admin lock and any temporary lock after failed sign-ins. Needs a recent sign-in."

      response "200", "unlocked" do
        schema "$ref" => "#/components/schemas/AdminUserEnvelope"
        before { target.suspend! }
        run_test!
      end
    end
  end

  path "/api/v1/admin/users/{user_id}/sign_out" do
    parameter name: :user_id, in: :path, schema: { type: :integer }
    let(:user_id) { create(:user).id }

    post "Sign an account out on every device (admins only)" do
      tags "Admin"
      produces "application/json"
      security [ { session_cookie: [], csrf_token: [] } ]
      description "Ends every session; the user can sign in again. Needs a recent sign-in."

      response "200", "signed out" do
        schema "$ref" => "#/components/schemas/AdminUserEnvelope"
        run_test!
      end

      response "403", "re-authentication needed" do
        schema "$ref" => "#/components/schemas/Problem"
        before { travel 11.minutes }
        run_test!
      end
    end
  end
end
