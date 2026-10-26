require "swagger_helper"

RSpec.describe "Demo session API", type: :request do
  path "/api/v1/demo_session" do
    get "Is the shared demo account available?" do
      tags "Authentication"
      produces "application/json"

      response "200", "availability" do
        schema type: :object, required: %w[available], properties: { available: { type: :boolean } }

        before { create(:user, demo: true) }

        run_test! do
          expect(json).to eq("available" => true)
        end
      end
    end

    post "Sign in to the shared demo account" do
      tags "Authentication"
      produces "application/json"
      security [ { csrf_token: [] } ]
      description "No password needed. The demo's data is fictional, shared by all visitors and reset daily; " \
        "account settings and document uploads are locked."

      response "201", "signed in to the demo" do
        schema type: :object, required: %w[user], properties: { user: { "$ref" => "#/components/schemas/User" } }

        let!(:demo) { create(:user, demo: true) }

        run_test! do
          expect(json["user"]).to include("id" => demo.id, "demo" => true)
          get "/api/v1/me"
          expect(response).to have_http_status(:ok)
        end
      end

      response "404", "no demo account on this server" do
        schema "$ref" => "#/components/schemas/Problem"
        run_test!
      end
    end
  end

  it "reports the demo as unavailable when there is no demo account" do
    get "/api/v1/demo_session"
    expect(response.parsed_body).to eq("available" => false)
  end

  it "neither emails the demo account about new devices nor logs visitors' sign-ins" do
    demo = create(:user, demo: true)

    expect { post "/api/v1/demo_session" }.not_to have_enqueued_mail(UserMailer, :new_device_sign_in)
    expect(response).to have_http_status(:created)
    expect(demo.audit_events).to be_empty
    expect(demo.known_devices).to be_empty
  end

  it "limits demo sign-ins per address" do
    create(:user, demo: true)
    10.times { post "/api/v1/demo_session" }
    post "/api/v1/demo_session"

    expect(response).to have_http_status(:too_many_requests)
  end
end
