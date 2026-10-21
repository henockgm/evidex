require "swagger_helper"

RSpec.describe "Documents API", type: :request do
  let(:user) { create(:user) }

  before { sign_in(user) }

  def fixture(name, type)
    Rack::Test::UploadedFile.new(Rails.root.join("spec/fixtures/files", name), type)
  end

  path "/api/v1/documents" do
    get "List your career documents, newest first" do
      tags "Career library"
      produces "application/json"
      security [ { session_cookie: [] } ]

      response "200", "documents" do
        schema type: :object, required: %w[documents],
          properties: { documents: { type: :array, items: { "$ref" => "#/components/schemas/Document" } } }

        before do
          create(:document, user:, title: "Old CV", created_at: 1.day.ago)
          create(:document, user:, title: "Project notes", kind: "project", fixture: "notes.md")
          create(:document, title: "Someone else's")
        end

        run_test! do
          expect(json["documents"].pluck("title")).to eq([ "Project notes", "Old CV" ])
        end
      end
    end

    post "Upload a document (PDF, Word .docx, Markdown or plain text, up to 10 MB)" do
      tags "Career library"
      consumes "multipart/form-data"
      produces "application/json"
      security [ { session_cookie: [], csrf_token: [] } ]
      description "The type is checked from the file's content. The first CV uploaded becomes the primary CV."
      # rswag documents the first form parameter's schema as the whole request body,
      # so it describes all fields; the other two only feed the test request.
      parameter name: :file, in: :formData, required: true, schema: {
        type: :object, required: %w[file],
        properties: {
          file: { type: :string, format: :binary },
          title: { type: :string, maxLength: 200, description: "Defaults to the file name" },
          kind: { type: :string, enum: Document::KINDS, default: "cv" }
        }
      }
      parameter name: :title, in: :formData, required: false
      parameter name: :kind, in: :formData, required: false

      response "201", "uploaded" do
        schema type: :object, required: %w[document], properties: { document: { "$ref" => "#/components/schemas/Document" } }
        let(:file) { fixture("cv.pdf", "application/pdf") }

        run_test! do
          expect(json["document"]).to include("title" => "cv", "kind" => "cv", "primary" => true, "status" => "pending",
            "filename" => "cv.pdf", "content_type" => "application/pdf")
        end
      end

      response "422", "not an allowed file type" do
        schema "$ref" => "#/components/schemas/Problem"
        let(:file) { fixture("fake.pdf", "application/pdf") }

        run_test! do
          expect(json["errors"]["file"].join).to include("must be a PDF")
          expect(Document.count).to eq(0)
        end
      end
    end
  end

  path "/api/v1/documents/{id}" do
    parameter name: :id, in: :path, type: :integer

    patch "Rename, re-tag or set as primary CV" do
      tags "Career library"
      consumes "application/json"
      produces "application/json"
      security [ { session_cookie: [], csrf_token: [] } ]
      parameter name: :body, in: :body, schema: {
        type: :object, required: %w[document],
        properties: { document: { type: :object, properties: {
          title: { type: :string, maxLength: 200 },
          kind: { type: :string, enum: Document::KINDS },
          primary: { type: :boolean, description: "true makes this the primary CV (the previous one stops being primary)" }
        } } }
      }

      let!(:old_primary) { create(:document, user:, primary: true) }
      let(:document) { create(:document, user:, title: "New CV") }
      let(:id) { document.id }

      response "200", "updated" do
        schema type: :object, required: %w[document], properties: { document: { "$ref" => "#/components/schemas/Document" } }
        let(:body) { { document: { title: "CV 2026", primary: true } } }

        run_test! do
          expect(document.reload).to have_attributes(title: "CV 2026", primary: true)
          expect(old_primary.reload.primary).to be(false)
        end
      end

      response "422", "invalid" do
        schema "$ref" => "#/components/schemas/Problem"
        let(:body) { { document: { kind: "certificate", primary: true } } }
        run_test!
      end

      response "404", "someone else's document" do
        schema "$ref" => "#/components/schemas/Problem"
        let(:id) { create(:document).id }
        let(:body) { { document: { title: "Mine now" } } }
        run_test!
      end
    end

    delete "Delete a document and its file" do
      tags "Career library"
      security [ { session_cookie: [], csrf_token: [] } ]

      response "204", "deleted" do
        let(:id) { create(:document, user:).id }

        run_test! do
          expect(Document.exists?(id)).to be(false)
        end
      end
    end
  end

  path "/api/v1/documents/{id}/file" do
    parameter name: :id, in: :path, type: :integer

    get "Download the original file" do
      tags "Career library"
      produces "application/octet-stream"
      security [ { session_cookie: [] } ]

      response "200", "the file, as an attachment" do
        let(:id) { create(:document, user:).id }

        run_test! do
          expect(response.headers["Content-Disposition"]).to start_with("attachment")
          expect(response.body).to start_with("%PDF-1.4")
        end
      end

      response "404", "someone else's document" do
        let(:id) { create(:document).id }
        run_test!
      end
    end
  end

  path "/api/v1/documents/{id}/text" do
    parameter name: :id, in: :path, type: :integer

    get "Extracted text, page by page" do
      tags "Career library"
      produces "application/json"
      security [ { session_cookie: [] } ]

      response "200", "pages (one entry for non-PDF files)" do
        schema type: :object, required: %w[pages], properties: { pages: { type: :array, items: { type: :string } } }
        let(:id) { create(:document, user:).tap { |d| ProcessDocumentJob.perform_now(d.id) }.id }

        run_test! do
          expect(json["pages"].first).to include("Alex Example")
        end
      end
    end
  end

  path "/api/v1/documents/{id}/chunks" do
    parameter name: :id, in: :path, type: :integer

    get "Passages the document was split into" do
      tags "Career library"
      produces "application/json"
      security [ { session_cookie: [] } ]

      response "200", "chunks in reading order" do
        schema type: :object, required: %w[chunks], properties: {
          chunks: { type: :array, items: {
            type: :object, required: %w[id position page section content],
            properties: {
              id: { type: :integer }, position: { type: :integer },
              page: { type: :integer, nullable: true, description: "1-based page, PDFs only" },
              section: { type: :string, nullable: true, description: "Nearest heading above the passage" },
              content: { type: :string }
            }
          } }
        }
        let(:id) { create(:document, user:).tap { |d| ProcessDocumentJob.perform_now(d.id) }.id }

        run_test! do
          expect(json["chunks"].pluck("section")).to eq(%w[Experience Skills Education])
        end
      end

      response "404", "someone else's document" do
        let(:id) { create(:document).id }
        run_test!
      end
    end
  end

  path "/api/v1/documents/{id}/retry" do
    parameter name: :id, in: :path, type: :integer

    post "Read a document again after a failure" do
      tags "Career library"
      produces "application/json"
      security [ { session_cookie: [], csrf_token: [] } ]

      response "202", "queued again" do
        schema type: :object, required: %w[document], properties: { document: { "$ref" => "#/components/schemas/Document" } }
        let(:id) { create(:document, user:).tap { |d| d.update_columns(status: "failed", error: "Boom") }.id }

        run_test! do
          expect(json["document"]).to include("status" => "pending", "error" => nil)
          expect(ProcessDocumentJob).to have_been_enqueued.with(id).at_least(:once)
        end
      end

      response "409", "not failed" do
        schema "$ref" => "#/components/schemas/Problem"
        let(:id) { create(:document, user:).id }
        run_test!
      end
    end
  end

  it "has no public Active Storage routes" do
    expect(Rails.application.routes.routes.map(&:path).map(&:spec).map(&:to_s).grep(/active_storage/)).to be_empty
  end

  it "requires signing in" do
    delete "/api/v1/session"
    get "/api/v1/documents"
    expect(response).to have_http_status(:unauthorized)
  end
end
