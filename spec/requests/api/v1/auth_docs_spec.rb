require "swagger_helper"

# OpenAPI documentation for the authentication endpoints. Behaviour in depth is
# covered in spec/requests/auth/.
RSpec.describe "Authentication API", type: :request do
  let(:user) { create(:user, email_address: "ada@example.com") }

  path "/api/v1/csrf_token" do
    get "Get a CSRF token for state-changing requests" do
      tags "Authentication"
      produces "application/json"

      response "200", "token issued" do
        schema type: :object, required: %w[csrf_token], properties: { csrf_token: { type: :string } }
        run_test!
      end
    end
  end

  path "/api/v1/auth/providers" do
    get "List enabled Google/Microsoft sign-in providers" do
      tags "Authentication"
      produces "application/json"
      description "Start a provider sign-in with a browser form POST to `path` that includes `authenticity_token`. " \
        "A signed-in user without a password or two-factor sign-in posts to `reauthenticate_path` instead to confirm it's them."

      response "200", "providers" do
        schema type: :object, required: %w[providers], properties: {
          providers: { type: :array, items: { type: :object, required: %w[id label path reauthenticate_path], properties: {
            id: { type: :string }, label: { type: :string }, path: { type: :string }, reauthenticate_path: { type: :string }
          } } }
        }
        run_test!
      end
    end
  end

  path "/api/v1/registration" do
    post "Register with email and password" do
      tags "Authentication"
      consumes "application/json"
      produces "application/json"
      security [ { csrf_token: [] } ]
      description "Always 202 for a well-formed request, whether or not the email is already registered."
      parameter name: :body, in: :body, schema: {
        type: :object, required: %w[email_address password],
        properties: {
          email_address: { type: :string, format: :email },
          password: { type: :string, minLength: 12, description: "12+ characters, max 72 bytes, not in a known breach" },
          name: { type: :string, maxLength: 100 }
        }
      }

      response "202", "confirmation email sent" do
        schema "$ref" => "#/components/schemas/Message"
        let(:body) { { email_address: "new@example.com", password: AuthHelpers::PASSWORD, name: "Ada" } }
        run_test!
      end

      response "422", "invalid password" do
        schema "$ref" => "#/components/schemas/Problem"
        let(:body) { { email_address: "new@example.com", password: "short" } }
        run_test!
      end
    end
  end

  path "/api/v1/session" do
    post "Sign in with email and password" do
      tags "Authentication"
      consumes "application/json"
      produces "application/json"
      security [ { csrf_token: [] } ]
      parameter name: :body, in: :body, schema: {
        type: :object, required: %w[email_address password],
        properties: { email_address: { type: :string, format: :email }, password: { type: :string } }
      }

      response "201", "signed in; sets the session cookie" do
        schema "$ref" => "#/components/schemas/UserEnvelope"
        let(:body) { { email_address: user.email_address, password: AuthHelpers::PASSWORD } }
        run_test!
      end

      response "202", "password accepted; a second factor is required" do
        schema type: :object, required: %w[second_factor_required], properties: { second_factor_required: { type: :boolean } }
        let(:body) { { email_address: user.email_address, password: AuthHelpers::PASSWORD } }
        before { user.enable_two_factor!(ROTP::Base32.random) }
        run_test!
      end

      response "401", "invalid credentials or locked account" do
        schema "$ref" => "#/components/schemas/Problem"
        let(:body) { { email_address: user.email_address, password: "wrong password!!" } }
        run_test!
      end
    end

    delete "Sign out" do
      tags "Authentication"
      security [ { session_cookie: [], csrf_token: [] } ]

      response "204", "signed out" do
        before { sign_in(user) }
        run_test!
      end
    end
  end

  path "/api/v1/session/second_factor" do
    post "Second sign-in step: an authenticator or recovery code" do
      tags "Authentication"
      consumes "application/json"
      produces "application/json"
      security [ { csrf_token: [] } ]
      description "Follows a 202 from POST /api/v1/session (or a Google/Microsoft redirect to /login/verify). Valid for 5 minutes and 5 attempts; wrong codes count toward account lockout."
      parameter name: :body, in: :body, schema: { type: :object, required: %w[code], properties: { code: { type: :string, description: "6-digit code or a recovery code" } } }

      let(:secret) { ROTP::Base32.random }

      before do
        user.enable_two_factor!(secret)
        post "/api/v1/session", params: { email_address: user.email_address, password: AuthHelpers::PASSWORD }, as: :json
      end

      response "201", "signed in" do
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

  path "/api/v1/email_verification" do
    post "Confirm an email address with the emailed token" do
      tags "Authentication"
      consumes "application/json"
      produces "application/json"
      security [ { csrf_token: [] } ]
      parameter name: :body, in: :body, schema: { type: :object, required: %w[token], properties: { token: { type: :string } } }

      response "200", "confirmed" do
        schema "$ref" => "#/components/schemas/Message"
        let(:body) { { token: create(:user, :unverified).generate_token_for(:email_verification) } }
        run_test!
      end

      response "422", "invalid or expired token" do
        schema "$ref" => "#/components/schemas/Problem"
        let(:body) { { token: "invalid" } }
        run_test!
      end
    end
  end

  path "/api/v1/email_verification/resend" do
    post "Resend the confirmation email" do
      tags "Authentication"
      produces "application/json"
      security [ { session_cookie: [], csrf_token: [] } ]

      response "202", "sent" do
        schema "$ref" => "#/components/schemas/Message"
        before { sign_in(create(:user, :unverified, email_address: "unverified@example.com")) }
        run_test!
      end
    end
  end

  path "/api/v1/password_reset" do
    post "Request a password reset email" do
      tags "Authentication"
      consumes "application/json"
      produces "application/json"
      security [ { csrf_token: [] } ]
      description "Always 202, whether or not the account exists."
      parameter name: :body, in: :body, schema: { type: :object, required: %w[email_address], properties: { email_address: { type: :string } } }

      response "202", "email sent if the account exists" do
        schema "$ref" => "#/components/schemas/Message"
        let(:body) { { email_address: user.email_address } }
        run_test!
      end
    end

    patch "Set a new password with the emailed token" do
      tags "Authentication"
      consumes "application/json"
      produces "application/json"
      security [ { csrf_token: [] } ]
      parameter name: :body, in: :body, schema: {
        type: :object, required: %w[token password],
        properties: { token: { type: :string }, password: { type: :string, minLength: 12 } }
      }

      response "200", "password reset; all sessions signed out" do
        schema "$ref" => "#/components/schemas/Message"
        let(:body) { { token: user.password_reset_token, password: "a brand new long password" } }
        run_test!
      end

      response "422", "invalid token or password" do
        schema "$ref" => "#/components/schemas/Problem"
        let(:body) { { token: "invalid", password: "a brand new long password" } }
        run_test!
      end
    end
  end
end
