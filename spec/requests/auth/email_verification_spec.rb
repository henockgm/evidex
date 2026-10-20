require "rails_helper"

RSpec.describe "Email verification", type: :request do
  let(:user) { create(:user, :unverified) }

  it "verifies the email with a valid token, once" do
    token = user.generate_token_for(:email_verification)

    post "/api/v1/email_verification", params: { token: }, as: :json
    expect(response).to have_http_status(:ok)
    expect(user.reload).to be_verified

    post "/api/v1/email_verification", params: { token: }, as: :json
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "rejects a tampered token" do
    post "/api/v1/email_verification", params: { token: "nope" }, as: :json
    expect(response).to have_http_status(:unprocessable_content)
  end

  it "resends the confirmation email to a signed-in user" do
    sign_in(user)

    expect { post "/api/v1/email_verification/resend" }.to have_enqueued_mail(UserMailer, :email_verification)
    expect(response).to have_http_status(:accepted)
  end

  it "limits resends" do
    sign_in(user)
    3.times { post "/api/v1/email_verification/resend" }
    post "/api/v1/email_verification/resend"
    expect(response).to have_http_status(:too_many_requests)
  end
end
