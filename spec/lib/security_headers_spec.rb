require "rails_helper"
require "evidex/security_headers"

RSpec.describe Evidex::SecurityHeaders do
  let(:app) { ->(_env) { [ 200, {}, [ "ok" ] ] } }

  def headers_for(middleware, path = "/")
    middleware.call(Rack::MockRequest.env_for(path))[1]
  end

  it "only reports violations when asked to (development)" do
    headers = headers_for(described_class.new(app, report_only: true))

    expect(headers).to have_key("content-security-policy-report-only")
    expect(headers).not_to have_key("content-security-policy")
  end

  it "upgrades insecure requests when asked to (production)" do
    expect(headers_for(described_class.new(app, upgrade_insecure_requests: true))["content-security-policy"])
      .to end_with("; upgrade-insecure-requests")
  end
end
