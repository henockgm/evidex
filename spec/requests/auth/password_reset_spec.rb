require "rails_helper"

RSpec.describe "Password reset", type: :request do
  let!(:user) { create(:user, :unverified, email_address: "ada@example.com") }
  let(:new_password) { "a brand new long password" }

  it "emails a reset link without revealing whether the account exists" do
    expect { post "/api/v1/password_reset", params: { email_address: "ada@example.com" }, as: :json }
      .to have_enqueued_mail(UserMailer, :password_reset)
    known = [ response.status, json ]

    expect { post "/api/v1/password_reset", params: { email_address: "nobody@example.com" }, as: :json }
      .not_to have_enqueued_mail
    expect([ response.status, json ]).to eq(known)
  end

  it "sets the new password, verifies the email and signs out every device" do
    create(:session, user:)
    token = user.password_reset_token

    patch "/api/v1/password_reset", params: { token:, password: new_password }, as: :json

    expect(response).to have_http_status(:ok)
    expect(user.reload.authenticate(new_password)).to be_truthy
    expect(user).to be_verified
    expect(user.sessions).to be_empty
  end

  it "works only once" do
    token = user.password_reset_token
    patch "/api/v1/password_reset", params: { token:, password: new_password }, as: :json
    patch "/api/v1/password_reset", params: { token:, password: "another long password" }, as: :json

    expect(response).to have_http_status(:unprocessable_content)
  end

  it "expires after 15 minutes" do
    token = user.password_reset_token
    travel 16.minutes do
      patch "/api/v1/password_reset", params: { token:, password: new_password }, as: :json
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  it "validates the new password" do
    patch "/api/v1/password_reset", params: { token: user.password_reset_token, password: "short" }, as: :json
    expect(response).to have_http_status(:unprocessable_content)
    expect(json["errors"]).to have_key("password")
  end
end
