require "swagger_helper"

RSpec.describe "Job posting import API", type: :request do
  let(:user) { create(:user) }

  before do
    sign_in(user)
    allow(Resolv).to receive(:getaddresses).and_return([ "93.184.215.14" ])
  end

  path "/api/v1/job_posting_import" do
    post "Fetch a job ad from a link and return a draft posting" do
      tags "Job postings"
      consumes "application/json"
      produces "application/json"
      security [ { session_cookie: [], csrf_token: [] } ]
      description <<~TEXT
        Nothing is saved. Review the draft, then create it with POST /api/v1/job_postings.
        Only public http(s) pages are fetched; internal addresses, other ports and non-HTML files are refused.
      TEXT
      parameter name: :body, in: :body, schema: {
        type: :object, required: %w[url], properties: { url: { type: :string, format: :uri } }
      }

      response "200", "draft" do
        schema type: :object, required: %w[draft structured_data], properties: {
          draft: { "$ref" => "#/components/schemas/JobPostingInput" },
          structured_data: { type: :boolean, description: "The page had schema.org JobPosting data" }
        }
        let(:body) { { url: "https://jobs.example.com/rails" } }

        before do
          stub_request(:get, "https://jobs.example.com/rails").to_return(
            status: 200, headers: { "Content-Type" => "text/html" },
            body: %(<script type="application/ld+json">{"@type":"JobPosting","title":"Rails Developer","hiringOrganization":{"name":"Acme"},"description":"Build APIs"}</script>)
          )
        end

        run_test! do
          expect(json["draft"]).to include("title" => "Rails Developer", "company" => "Acme",
            "description" => "Build APIs", "source_url" => "https://jobs.example.com/rails")
          expect(json["structured_data"]).to be(true)
          expect(JobPosting.count).to eq(0)
        end
      end

      response "422", "couldn't fetch or refused" do
        schema "$ref" => "#/components/schemas/Problem"
        let(:body) { { url: "http://intranet.example.com/" } }

        before { allow(Resolv).to receive(:getaddresses).with("intranet.example.com").and_return([ "10.0.0.8" ]) }

        run_test! do
          expect(json["detail"]).to eq("That address isn't on the public internet")
        end
      end
    end
  end

  it "limits imports per user" do
    stub_request(:get, "https://jobs.example.com/rails").to_return(status: 200, body: "<p>x</p>", headers: { "Content-Type" => "text/html" })
    10.times { post "/api/v1/job_posting_import", params: { url: "https://jobs.example.com/rails" }, as: :json }
    post "/api/v1/job_posting_import", params: { url: "https://jobs.example.com/rails" }, as: :json

    expect(response).to have_http_status(:too_many_requests)
  end
end
