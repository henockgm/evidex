require "rails_helper"

RSpec.describe "Registration", type: :request do
  let(:params) { { email_address: "Ada@Example.com", name: "Ada", password: AuthHelpers::PASSWORD } }

  it "creates an unverified account and sends a confirmation email" do
    expect { post "/api/v1/registration", params:, as: :json }
      .to change(User, :count).by(1)
      .and have_enqueued_mail(UserMailer, :email_verification)

    expect(response).to have_http_status(:accepted)
    user = User.last
    expect(user.email_address).to eq("ada@example.com")
    expect(user).not_to be_verified
    expect(AuditEvent.last.action).to eq("registered")
  end

  it "doesn't reveal that an email is already registered" do
    existing = create(:user, email_address: "ada@example.com")

    expect { post "/api/v1/registration", params:, as: :json }
      .to not_change(User, :count)
      .and have_enqueued_mail(UserMailer, :registration_attempt).with(params: { user: existing }, args: [])

    expect(response).to have_http_status(:accepted)
    expect(json["message"]).to eq(Api::V1::RegistrationsController::MESSAGE)
  end

  it "returns field errors for a weak password" do
    post "/api/v1/registration", params: params.merge(password: "short"), as: :json

    expect(response).to have_http_status(:unprocessable_content)
    expect(response.media_type).to eq("application/problem+json")
    expect(json["errors"]["password"]).to include(a_string_matching(/too short/))
  end

  it "rate limits registrations per IP" do
    5.times { |i| post "/api/v1/registration", params: params.merge(email_address: "u#{i}@example.com"), as: :json }
    post "/api/v1/registration", params: params.merge(email_address: "u6@example.com"), as: :json

    expect(response).to have_http_status(:too_many_requests)
  end
end

RSpec.describe "User mailer links", type: :mailer do
  it "points the confirmation link at the SPA" do
    user = create(:user, :unverified)
    mail = UserMailer.with(user:).email_verification

    expect(mail.to).to eq([ user.email_address ])
    expect(mail.body.encoded).to match(%r{http://localhost:5173/verify-email\?token=\S+})
  end
end
