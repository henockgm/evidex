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

  path "/api/v1/me/two_factor/setup" do
    post "Start setting up two-factor sign-in" do
      tags "Account"
      produces "application/json"
      security [ { session_cookie: [], csrf_token: [] } ]
      description "Returns a new secret as a QR code; nothing changes until it is confirmed with POST /api/v1/me/two_factor."

      response "200", "secret to add to an authenticator app" do
        schema type: :object, required: %w[secret otpauth_uri qr_code], properties: {
          secret: { type: :string }, otpauth_uri: { type: :string }, qr_code: { type: :string, description: "SVG as a data: URL" }
        }
        run_test!
      end
    end
  end

  path "/api/v1/me/two_factor" do
    post "Turn on two-factor sign-in by confirming a code" do
      tags "Account"
      consumes "application/json"
      produces "application/json"
      security [ { session_cookie: [], csrf_token: [] } ]
      parameter name: :body, in: :body, schema: { type: :object, required: %w[code], properties: { code: { type: :string } } }

      response "201", "on; the recovery codes are shown only now" do
        schema type: :object, required: %w[user recovery_codes], properties: {
          user: { "$ref" => "#/components/schemas/User" }, recovery_codes: { type: :array, items: { type: :string } }
        }
        let(:body) do
          post "/api/v1/me/two_factor/setup"
          { code: ROTP::TOTP.new(json["secret"]).now }
        end
        run_test!
      end
    end

    delete "Turn off two-factor sign-in" do
      tags "Account"
      consumes "application/json"
      produces "application/json"
      security [ { session_cookie: [], csrf_token: [] } ]
      parameter name: :body, in: :body, schema: { type: :object, required: %w[code], properties: { code: { type: :string, description: "Authenticator or recovery code" } } }

      let(:secret) { ROTP::Base32.random }
      before { user.enable_two_factor!(secret) }

      response "200", "off" do
        schema "$ref" => "#/components/schemas/UserEnvelope"
        let(:body) { { code: ROTP::TOTP.new(secret).now } }
        run_test!
      end

      response "422", "wrong code" do
        schema "$ref" => "#/components/schemas/Problem"
        let(:body) { { code: "000000" } }
        run_test!
      end
    end
  end

  path "/api/v1/me/two_factor/recovery_codes" do
    post "Replace the recovery codes" do
      tags "Account"
      consumes "application/json"
      produces "application/json"
      security [ { session_cookie: [], csrf_token: [] } ]
      parameter name: :body, in: :body, schema: { type: :object, required: %w[code], properties: { code: { type: :string, description: "Authenticator code" } } }

      let(:secret) { ROTP::Base32.random }
      before { user.enable_two_factor!(secret) }

      response "200", "new codes; the old ones stop working" do
        schema type: :object, required: %w[user recovery_codes], properties: {
          user: { "$ref" => "#/components/schemas/User" }, recovery_codes: { type: :array, items: { type: :string } }
        }
        let(:body) { { code: ROTP::TOTP.new(secret).now } }
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
