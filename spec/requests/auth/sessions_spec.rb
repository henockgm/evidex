require "rails_helper"

RSpec.describe "Sign in and out", type: :request do
  let!(:user) { create(:user, email_address: "ada@example.com") }

  def attempt(password)
    post "/api/v1/session", params: { email_address: "ADA@example.com", password: }, as: :json
  end

  it "signs in with a secure, HttpOnly session cookie" do
    attempt(AuthHelpers::PASSWORD)

    expect(response).to have_http_status(:created)
    expect(json["user"]["email_address"]).to eq("ada@example.com")
    cookie = response.headers["Set-Cookie"].then { |c| Array(c).join("\n") }
    expect(cookie).to match(/evidex_session=.*httponly/i).and match(/samesite=lax/i)

    get "/api/v1/me"
    expect(response).to have_http_status(:ok)
  end

  it "uses the same message for unknown emails and wrong passwords" do
    attempt("wrong password!!")
    wrong_password = json["title"]

    post "/api/v1/session", params: { email_address: "nobody@example.com", password: "whatever12345" }, as: :json
    expect(response).to have_http_status(:unauthorized)
    expect(json["title"]).to eq(wrong_password)
  end

  it "locks the account after 5 failed attempts, even for the right password" do
    4.times { attempt("wrong password!!") }
    expect { attempt("wrong password!!") }.to have_enqueued_mail(UserMailer, :account_locked)
    expect(user.reload).to be_locked

    attempt(AuthHelpers::PASSWORD)
    expect(response).to have_http_status(:unauthorized)

    travel 16.minutes do
      attempt(AuthHelpers::PASSWORD)
      expect(response).to have_http_status(:created)
      expect(user.reload.failed_sign_in_count).to eq(0)
    end
  end

  it "rate limits attempts per IP" do
    10.times { attempt("wrong password!!") }
    attempt(AuthHelpers::PASSWORD)
    expect(response).to have_http_status(:too_many_requests)
  end

  it "signs out and invalidates the server-side session" do
    sign_in(user)
    token_digest = user.sessions.last.token_digest

    delete "/api/v1/session"
    expect(response).to have_http_status(:no_content)
    expect(Session.exists?(token_digest:)).to be(false)

    get "/api/v1/me"
    expect(response).to have_http_status(:unauthorized)
  end

  it "rejects requests without a session" do
    get "/api/v1/me"
    expect(response).to have_http_status(:unauthorized)
    expect(json).to include("title" => "Authentication required", "status" => 401)
  end
end
