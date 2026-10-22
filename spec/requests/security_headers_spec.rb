require "rails_helper"

RSpec.describe "Security headers", type: :request do
  it "sends a strict policy and no-store on API responses" do
    get "/api/v1/status"

    policy = response.headers["content-security-policy"]
    expect(policy).to include("default-src 'self'", "script-src 'self';", "frame-ancestors 'none'", "object-src 'none'")
    expect(policy).not_to include("unsafe-inline")
    expect(response.headers).to include(
      "x-frame-options" => "DENY", "x-content-type-options" => "nosniff", "referrer-policy" => "same-origin",
      "cross-origin-opener-policy" => "same-origin", "cache-control" => "no-store"
    )
  end

  it "lets the sign-in form POST continue to Google and Microsoft" do
    get "/api/v1/status"

    expect(response.headers["content-security-policy"])
      .to include("form-action 'self' https://accounts.google.com https://login.microsoftonline.com https://login.live.com")
  end

  it "covers responses outside the API too, without no-store" do
    get "/up"

    expect(response.headers["content-security-policy"]).to include("default-src 'self'")
    expect(response.headers["cache-control"]).not_to eq("no-store")
  end

  it "allows inline code only for the Swagger UI" do
    get "/api-docs/index.html"

    expect(response.headers["content-security-policy"]).to include("script-src 'self' 'unsafe-inline'")
  end
end

RSpec.describe "Sensitive parameters in logs" do
  it "filters passwords, 2FA codes and tokens" do
    filter = ActiveSupport::ParameterFilter.new(Rails.application.config.filter_parameters)

    expect(filter.filter("password" => "a", "code" => "123456", "token" => "t", "confirm_email" => "e", "title" => "Dev"))
      .to eq("password" => "[FILTERED]", "code" => "[FILTERED]", "token" => "[FILTERED]", "confirm_email" => "[FILTERED]", "title" => "Dev")
  end
end
