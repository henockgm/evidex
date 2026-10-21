require "swagger_helper"

RSpec.describe "Library search API", type: :request do
  let(:user) { create(:user) }

  before do
    sign_in(user)
    create(:document, user:, fixture: "project.docx", title: "Route planner").tap { |d| ProcessDocumentJob.perform_now(d.id) }
  end

  path "/api/v1/library/search" do
    get "Search your library by meaning and by words" do
      tags "Career library"
      produces "application/json"
      security [ { session_cookie: [] } ]
      description "Hybrid search: vector similarity and full-text matches merged with Reciprocal Rank Fusion. Only your own, fully processed documents are searched."
      parameter name: :q, in: :query, type: :string, required: true

      response "200", "matching passages, best first" do
        schema type: :object, required: %w[results], properties: {
          results: { type: :array, items: {
            type: :object, required: %w[chunk_id document_id document_title page section content score matched_by],
            properties: {
              chunk_id: { type: :integer }, document_id: { type: :integer }, document_title: { type: :string },
              page: { type: :integer, nullable: true }, section: { type: :string, nullable: true },
              content: { type: :string }, score: { type: :number },
              matched_by: { type: :array, items: { type: :string, enum: %w[semantic keyword] } }
            }
          } }
        }
        let(:q) { "background jobs" }

        run_test! do
          expect(json["results"].first).to include("document_title" => "Route planner", "section" => "Project: Route planner API")
        end
      end
    end
  end

  it "limits searches per user" do
    30.times { get "/api/v1/library/search", params: { q: "Rails" } }
    get "/api/v1/library/search", params: { q: "Rails" }
    expect(response).to have_http_status(:too_many_requests)
  end
end
