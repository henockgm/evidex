require "rails_helper"

RSpec.describe "CSRF protection", type: :request do
  around do |example|
    ApplicationController.allow_forgery_protection = true
    example.run
  ensure
    ApplicationController.allow_forgery_protection = false
  end

  let!(:user) { create(:user) }
  let(:params) { { email_address: user.email_address, password: AuthHelpers::PASSWORD } }

  it "rejects state-changing requests without a token" do
    post "/api/v1/session", params:, as: :json
    expect(response).to have_http_status(:forbidden)
    expect(json["title"]).to eq("Invalid CSRF token")
  end

  it "accepts requests with the token from /api/v1/csrf_token" do
    get "/api/v1/csrf_token"
    token = json["csrf_token"]

    post "/api/v1/session", params:, headers: { "X-CSRF-Token" => token }, as: :json
    expect(response).to have_http_status(:created)
  end
end
