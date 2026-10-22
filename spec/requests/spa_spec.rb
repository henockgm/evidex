require "rails_helper"

RSpec.describe "Serving the React app", type: :request do
  around do |example|
    original = Rails.configuration.x.spa_root
    Rails.configuration.x.spa_root = Rails.root.join("spec/fixtures/spa")
    example.run
  ensure
    Rails.configuration.x.spa_root = original
  end

  it "serves index.html for the root and for any page URL, never cached without checking" do
    [ "/", "/postings/7", "/settings/security?linked=google_oauth2" ].each do |path|
      get path, headers: { "Accept" => "text/html" }

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("text/html")
      expect(response.body).to include('<div id="root">')
      expect(response.headers["cache-control"]).to eq("no-cache")
      expect(response.headers["content-security-policy"]).to include("script-src 'self';")
    end
  end

  it "leaves API, OAuth and non-HTML requests alone" do
    get "/api/v1/nope", headers: { "Accept" => "text/html" }
    expect(response.body).not_to include('<div id="root">')

    get "/assets/missing.js"
    expect(response).to have_http_status(:not_found)

    get "/api/v1/status"
    expect(response.parsed_body).to include("name" => "Evidex")
  end

  it "explains when the frontend hasn't been built" do
    Rails.configuration.x.spa_root = Rails.root.join("tmp/no-such-build")

    get "/postings", headers: { "Accept" => "text/html" }

    expect(response).to have_http_status(:not_found)
    expect(response.body).to include("npm run build")
  end
end
