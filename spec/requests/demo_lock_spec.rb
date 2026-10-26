require "rails_helper"

RSpec.describe "Demo account limits", type: :request do
  let(:demo) { create(:user, demo: true) }

  before { sign_in(demo) }

  it "locks account settings, which would also show other visitors' sessions and activity" do
    get "/api/v1/me"
    expect(response).to have_http_status(:ok)

    requests = [
      [ :get, "/api/v1/me/sessions" ], [ :get, "/api/v1/me/activity" ], [ :get, "/api/v1/me/identities" ],
      [ :patch, "/api/v1/me/password" ], [ :post, "/api/v1/me/two_factor/setup" ], [ :delete, "/api/v1/me" ]
    ]
    requests.each do |verb, path|
      send(verb, path, as: :json)
      expect(response).to have_http_status(:forbidden), "#{verb} #{path} answered #{response.status}"
      expect(response.parsed_body).to include("type" => "urn:evidex:problem:demo-locked", "title" => "Not available in the demo")
    end
    expect(User.exists?(demo.id)).to be(true)
  end

  it "lets visitors read the library but not upload or change documents" do
    document = create(:document, user: demo)

    get "/api/v1/documents"
    expect(response).to have_http_status(:ok)

    post "/api/v1/documents", params: { document: { title: "My real CV", file: fixture_file_upload("cv.pdf", "application/pdf") } }
    expect(response).to have_http_status(:forbidden)

    delete "/api/v1/documents/#{document.id}"
    expect(response).to have_http_status(:forbidden)
    expect(Document.exists?(document.id)).to be(true)
  end

  it "gives the demo a smaller AI allowance shared by all its visitors" do
    expect(AiUsage.daily_limit(demo)).to eq(5)
    expect(AiUsage.daily_limit(create(:user))).to eq(20)

    5.times { AiUsage.create!(user: demo, feature: "match_report", model: "claude-opus-5-5", input_tokens: 10, output_tokens: 5) }
    expect(AiUsage.limit_reached?(demo)).to be(true)
  end

  it "leaves other accounts' settings alone" do
    sign_in(create(:user))
    get "/api/v1/me/sessions"
    expect(response).to have_http_status(:ok)
  end
end
