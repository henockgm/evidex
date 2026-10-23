module AuthHelpers
  PASSWORD = "correct horse battery staple".freeze

  def sign_in(user, password: PASSWORD)
    post "/api/v1/session", params: { email_address: user.email_address, password: }, as: :json
    if user.two_factor_enabled?
      expect(response).to have_http_status(:accepted)
      post "/api/v1/session/second_factor", params: { code: ROTP::TOTP.new(user.reload.otp_secret).now }, as: :json
    end
    expect(response).to have_http_status(:created)
  end

  def json
    response.parsed_body
  end
end

RSpec.configure do |config|
  config.include AuthHelpers, type: :request
  config.include ActiveJob::TestHelper

  config.before do
    Rails.configuration.x.rate_limit_store.clear
    ActionMailer::Base.deliveries.clear
  end
end

RSpec::Matchers.define_negated_matcher :not_change, :change
