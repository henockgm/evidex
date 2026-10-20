require "swagger_helper"

RSpec.describe "Account API", type: :request do
  let(:user) { create(:user) }

  before { sign_in(user) }

  path "/api/v1/me" do
    get "Current user" do
      tags "Account"
      produces "application/json"
      security [ { session_cookie: [] } ]

      response "200", "signed-in user" do
        schema "$ref" => "#/components/schemas/UserEnvelope"
        run_test!
      end

      response "401", "not signed in" do
        schema "$ref" => "#/components/schemas/Problem"
        before { delete "/api/v1/session" }
        run_test!
      end
    end

    delete "Delete the account and all its data" do
      tags "Account"
      consumes "application/json"
      security [ { session_cookie: [], csrf_token: [] } ]
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          password: { type: :string, description: "Required when the account has a password" },
          confirm_email: { type: :string, description: "Required instead of password for Google/Microsoft-only accounts" }
        }
      }

      response "204", "deleted" do
        let(:body) { { password: AuthHelpers::PASSWORD } }
        run_test!
      end

      response "422", "confirmation failed" do
        schema "$ref" => "#/components/schemas/Problem"
        let(:body) { { password: "wrong password!!" } }
        run_test!
      end
    end
  end

  path "/api/v1/me/password" do
    patch "Change password (or add one to a Google/Microsoft-only account)" do
      tags "Account"
      consumes "application/json"
      produces "application/json"
      security [ { session_cookie: [], csrf_token: [] } ]
      description "Signs out all other sessions. Accounts without a password must have signed in within the last 10 minutes."
      parameter name: :body, in: :body, schema: {
        type: :object, required: %w[password],
        properties: { current_password: { type: :string }, password: { type: :string, minLength: 12 } }
      }

      response "200", "changed" do
        schema "$ref" => "#/components/schemas/UserEnvelope"
        let(:body) { { current_password: AuthHelpers::PASSWORD, password: "an even longer new password" } }
        run_test!
      end

      response "422", "wrong current password or invalid new password" do
        schema "$ref" => "#/components/schemas/Problem"
        let(:body) { { current_password: "wrong password!!", password: "an even longer new password" } }
        run_test!
      end
    end
  end

  path "/api/v1/me/sessions" do
    get "List signed-in devices" do
      tags "Account"
      produces "application/json"
      security [ { session_cookie: [] } ]

      response "200", "sessions" do
        schema type: :object, required: %w[sessions],
          properties: { sessions: { type: :array, items: { "$ref" => "#/components/schemas/Session" } } }
        run_test!
      end
    end
  end

  path "/api/v1/me/sessions/{id}" do
    parameter name: :id, in: :path, type: :integer

    delete "Sign out one device" do
      tags "Account"
      security [ { session_cookie: [], csrf_token: [] } ]

      response "204", "revoked" do
        let(:id) { create(:session, user:).id }
        run_test!
      end

      response "404", "not one of your sessions" do
        schema "$ref" => "#/components/schemas/Problem"
        let(:id) { create(:session).id }
        run_test!
      end
    end
  end

  path "/api/v1/me/sessions/others" do
    delete "Sign out all other devices" do
      tags "Account"
      security [ { session_cookie: [], csrf_token: [] } ]

      response "204", "revoked" do
        run_test!
      end
    end
  end

  path "/api/v1/me/identities" do
    get "List connected Google/Microsoft accounts" do
      tags "Account"
      produces "application/json"
      security [ { session_cookie: [] } ]

      response "200", "identities" do
        schema type: :object, required: %w[identities],
          properties: { identities: { type: :array, items: { "$ref" => "#/components/schemas/Identity" } } }
        before { create(:identity, user:) }
        run_test!
      end
    end
  end

  path "/api/v1/me/identities/{id}" do
    parameter name: :id, in: :path, type: :integer

    delete "Disconnect a Google/Microsoft account" do
      tags "Account"
      security [ { session_cookie: [], csrf_token: [] } ]
      description "Refused when it is the account's only sign-in method."

      response "204", "disconnected" do
        let(:id) { create(:identity, user:).id }
        run_test!
      end
    end
  end
end
