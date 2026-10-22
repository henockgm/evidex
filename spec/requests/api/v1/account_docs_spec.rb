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
      description "Needs a sign-in or re-authentication (POST /api/v1/me/reauthentication) from the last 10 minutes; otherwise 403 with type urn:evidex:problem:reauthentication-required."
      parameter name: :body, in: :body, schema: {
        type: :object, required: %w[confirm_email],
        properties: { confirm_email: { type: :string, description: "The account's email address, typed out" } }
      }

      response "204", "deleted" do
        let(:body) { { confirm_email: user.email_address } }
        run_test!
      end

      response "403", "re-authentication needed" do
        schema "$ref" => "#/components/schemas/Problem"
        let(:body) { { confirm_email: user.email_address } }
        before { travel 11.minutes }
        run_test!
      end

      response "422", "email doesn't match" do
        schema "$ref" => "#/components/schemas/Problem"
        let(:body) { { confirm_email: "someone@else.example" } }
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
      description "Signs out all other sessions. Needs a sign-in or re-authentication (POST /api/v1/me/reauthentication) from the last 10 minutes; otherwise 403 with type urn:evidex:problem:reauthentication-required."
      parameter name: :body, in: :body, schema: {
        type: :object, required: %w[password],
        properties: { password: { type: :string, minLength: 12 } }
      }

      response "200", "changed" do
        schema "$ref" => "#/components/schemas/UserEnvelope"
        let(:body) { { password: "an even longer new password" } }
        run_test!
      end

      response "422", "invalid new password" do
        schema "$ref" => "#/components/schemas/Problem"
        let(:body) { { password: "too short" } }
        run_test!
      end
    end
  end

  path "/api/v1/me/reauthentication" do
    post "Confirm it's you before a sensitive change (sudo mode)" do
      tags "Account"
      consumes "application/json"
      produces "application/json"
      security [ { session_cookie: [], csrf_token: [] } ]
      description "Asks for the password, plus a code when two-factor sign-in is on. Accounts without a password give a code, " \
        "or sign in with Google/Microsoft again. Sensitive changes are then allowed for 10 minutes."
      parameter name: :body, in: :body, schema: {
        type: :object,
        properties: {
          password: { type: :string, description: "Required when the account has a password" },
          code: { type: :string, description: "Authenticator or recovery code; required when two-factor sign-in is on" }
        }
      }

      response "201", "confirmed" do
        schema type: :object, required: %w[recently_authenticated_until],
          properties: { recently_authenticated_until: { type: :string, format: "date-time" } }
        let(:body) { { password: AuthHelpers::PASSWORD } }
        run_test!
      end

      response "422", "wrong password or code" do
        schema "$ref" => "#/components/schemas/Problem"
        let(:body) { { password: "wrong password!!" } }
        run_test!
      end
    end
  end

  path "/api/v1/me/two_factor/setup" do
    post "Start setting up two-factor sign-in" do
      tags "Account"
      produces "application/json"
      security [ { session_cookie: [], csrf_token: [] } ]
      description "Returns a new secret as a QR code; nothing changes until it is confirmed with POST /api/v1/me/two_factor. Needs a sign-in or re-authentication (POST /api/v1/me/reauthentication) from the last 10 minutes; otherwise 403 with type urn:evidex:problem:reauthentication-required."

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
      produces "application/json"
      security [ { session_cookie: [], csrf_token: [] } ]
      description "Needs a sign-in or re-authentication (POST /api/v1/me/reauthentication) from the last 10 minutes; otherwise 403 with type urn:evidex:problem:reauthentication-required."

      before { user.enable_two_factor!(ROTP::Base32.random) }

      response "200", "off" do
        schema "$ref" => "#/components/schemas/UserEnvelope"
        run_test!
      end
    end
  end

  path "/api/v1/me/two_factor/recovery_codes" do
    post "Replace the recovery codes" do
      tags "Account"
      produces "application/json"
      security [ { session_cookie: [], csrf_token: [] } ]
      description "Needs a sign-in or re-authentication (POST /api/v1/me/reauthentication) from the last 10 minutes; otherwise 403 with type urn:evidex:problem:reauthentication-required."

      before { user.enable_two_factor!(ROTP::Base32.random) }

      response "200", "new codes; the old ones stop working" do
        schema type: :object, required: %w[user recovery_codes], properties: {
          user: { "$ref" => "#/components/schemas/User" }, recovery_codes: { type: :array, items: { type: :string } }
        }
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
      description "Refused when it is the account's only sign-in method. Needs a sign-in or re-authentication (POST /api/v1/me/reauthentication) from the last 10 minutes; otherwise 403 with type urn:evidex:problem:reauthentication-required."

      response "204", "disconnected" do
        let(:id) { create(:identity, user:).id }
        run_test!
      end
    end
  end
end
