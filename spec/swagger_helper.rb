# frozen_string_literal: true

require 'rails_helper'

RSpec.configure do |config|
  # Specify a root folder where Swagger JSON files are generated
  # NOTE: If you're using the rswag-api to serve API descriptions, you'll need
  # to ensure that it's configured to serve Swagger from the same folder
  config.openapi_root = Rails.root.join('swagger').to_s

  # Define one or more Swagger documents and provide global metadata for each one
  # When you run the 'rswag:specs:swaggerize' rake task, the complete Swagger will
  # be generated at the provided relative path under openapi_root
  # By default, the operations defined in spec files are added to the first
  # document below. You can override this behavior by adding a openapi_spec tag to the
  # the root example_group in your specs, e.g. describe '...', openapi_spec: 'v2/swagger.json'
  config.openapi_specs = {
    'v1/swagger.yaml' => {
      openapi: '3.0.1',
      info: {
        title: 'Evidex API',
        version: 'v1',
        description: 'Evidence-based job applications: postings, career library, match reports and application tracking.'
      },
      paths: {},
      components: {
        securitySchemes: {
          session_cookie: {
            type: :apiKey, in: :cookie, name: "evidex_session",
            description: "Set by POST /api/v1/session or Google/Microsoft sign-in. HttpOnly."
          },
          csrf_token: {
            type: :apiKey, in: :header, name: "X-CSRF-Token",
            description: "Required on POST/PATCH/DELETE. Get it from GET /api/v1/csrf_token."
          }
        },
        schemas: {
          Problem: {
            type: :object,
            description: "RFC 9457 problem details",
            required: %w[type title status],
            properties: {
              type: { type: :string, example: "about:blank" },
              title: { type: :string },
              status: { type: :integer },
              detail: { type: :string },
              errors: { type: :object, additionalProperties: { type: :array, items: { type: :string } } }
            }
          },
          Message: {
            type: :object, required: %w[message],
            properties: { message: { type: :string } }
          },
          Identity: {
            type: :object,
            required: %w[id provider label created_at],
            properties: {
              id: { type: :integer },
              provider: { type: :string, enum: %w[google_oauth2 entra_id] },
              label: { type: :string, example: "Google" },
              email: { type: :string, nullable: true },
              created_at: { type: :string, format: "date-time" }
            }
          },
          User: {
            type: :object,
            required: %w[id email_address email_verified has_password ai_configured identities created_at],
            properties: {
              id: { type: :integer },
              email_address: { type: :string, format: :email },
              name: { type: :string, nullable: true },
              email_verified: { type: :boolean },
              has_password: { type: :boolean },
              ai_configured: { type: :boolean, description: "The server has an AI provider configured" },
              identities: { type: :array, items: { "$ref" => "#/components/schemas/Identity" } },
              created_at: { type: :string, format: "date-time" }
            }
          },
          UserEnvelope: {
            type: :object, required: %w[user],
            properties: { user: { "$ref" => "#/components/schemas/User" } }
          },
          JobPostingSummary: {
            type: :object,
            required: %w[id title company status created_at updated_at],
            properties: {
              id: { type: :integer },
              title: { type: :string },
              company: { type: :string },
              location: { type: :string, nullable: true },
              work_model: { type: :string, enum: JobPosting::WORK_MODELS, nullable: true },
              deadline: { type: :string, format: :date, nullable: true },
              source_url: { type: :string, nullable: true },
              status: { "$ref" => "#/components/schemas/ApplicationStatus" },
              created_at: { type: :string, format: "date-time" },
              updated_at: { type: :string, format: "date-time" }
            }
          },
          ApplicationStatus: {
            type: :string, enum: JobApplication::STATUSES,
            description: "saved → preparing → applied → interviewing → offer, or rejected / withdrawn"
          },
          JobApplication: {
            type: :object,
            required: %w[id status available_transitions applied_on next_action next_action_on notes links contacts interviews events],
            properties: {
              id: { type: :integer },
              status: { "$ref" => "#/components/schemas/ApplicationStatus" },
              applied_on: { type: :string, format: :date, nullable: true },
              next_action: { type: :string, nullable: true },
              next_action_on: { type: :string, format: :date, nullable: true },
              notes: { type: :string, nullable: true },
              links: { type: :array, items: { "$ref" => "#/components/schemas/ApplicationLink" } },
              contacts: { type: :array, items: { "$ref" => "#/components/schemas/ApplicationContact" } },
              interviews: { type: :array, description: "Oldest first", items: { "$ref" => "#/components/schemas/Interview" } },
              available_transitions: {
                type: :array, items: { "$ref" => "#/components/schemas/ApplicationStatus" },
                description: "Statuses this application can move to next"
              },
              events: {
                type: :array, description: "Timeline, oldest first",
                items: {
                  type: :object, required: %w[id to_status created_at],
                  properties: {
                    id: { type: :integer },
                    from_status: { allOf: [ { "$ref" => "#/components/schemas/ApplicationStatus" } ], nullable: true },
                    to_status: { "$ref" => "#/components/schemas/ApplicationStatus" },
                    note: { type: :string, nullable: true },
                    created_at: { type: :string, format: "date-time" }
                  }
                }
              }
            }
          },
          MatchReport: {
            type: :object,
            required: %w[id job_posting_id version status error model counts strengths gaps created_at completed_at matches],
            properties: {
              id: { type: :integer },
              job_posting_id: { type: :integer },
              version: { type: :integer },
              status: { type: :string, enum: MatchReport::STATUSES },
              error: { type: :string, nullable: true },
              model: { type: :string, nullable: true },
              counts: { type: :object, required: RequirementMatch::VERDICTS,
                        properties: RequirementMatch::VERDICTS.index_with { { type: :integer } } },
              strengths: { type: :array, items: { type: :string } },
              gaps: { type: :array, items: { type: :string } },
              created_at: { type: :string, format: "date-time" },
              completed_at: { type: :string, format: "date-time", nullable: true },
              matches: { type: :array, items: { "$ref" => "#/components/schemas/RequirementMatch" } }
            }
          },
          RequirementMatch: {
            type: :object,
            required: %w[id requirement_id requirement_kind requirement_text verdict ai_verdict user_verdict user_note reasoning citations],
            properties: {
              id: { type: :integer },
              requirement_id: { type: :integer, nullable: true, description: "null once the requirement is deleted" },
              requirement_kind: { type: :string, enum: Requirement::KINDS },
              requirement_text: { type: :string, description: "As it was when the report ran" },
              verdict: { type: :string, enum: RequirementMatch::VERDICTS, description: "The user's verdict if set, else the AI's" },
              ai_verdict: { type: :string, enum: RequirementMatch::VERDICTS },
              user_verdict: { type: :string, enum: RequirementMatch::VERDICTS, nullable: true },
              user_note: { type: :string, nullable: true },
              reasoning: { type: :string, nullable: true },
              citations: { type: :array, items: {
                type: :object, required: %w[id document_id document_title page section excerpt],
                properties: {
                  id: { type: :integer },
                  document_id: { type: :integer, nullable: true },
                  document_title: { type: :string },
                  page: { type: :integer, nullable: true },
                  section: { type: :string, nullable: true },
                  excerpt: { type: :string, description: "The cited passage, saved when the report ran" }
                }
              } }
            }
          },
          Document: {
            type: :object,
            required: %w[id title kind primary status error filename content_type byte_size page_count character_count chunk_count processed_at created_at updated_at],
            properties: {
              id: { type: :integer },
              title: { type: :string },
              kind: { type: :string, enum: Document::KINDS },
              primary: { type: :boolean, description: "The user's main CV" },
              status: { type: :string, enum: Document::STATUSES, description: "Text extraction and indexing progress" },
              error: { type: :string, nullable: true },
              filename: { type: :string },
              content_type: { type: :string },
              byte_size: { type: :integer },
              page_count: { type: :integer, description: "Pages of extracted text (1 for non-PDF files)" },
              character_count: { type: :integer },
              chunk_count: { type: :integer, description: "Passages indexed for search and matching" },
              processed_at: { type: :string, format: "date-time", nullable: true },
              created_at: { type: :string, format: "date-time" },
              updated_at: { type: :string, format: "date-time" }
            }
          },
          Interview: {
            type: :object, required: %w[id round scheduled_at format location status notes],
            properties: {
              id: { type: :integer },
              round: { type: :string, nullable: true },
              scheduled_at: { type: :string, format: "date-time" },
              format: { type: :string, enum: Interview::FORMATS, nullable: true },
              location: { type: :string, nullable: true },
              status: { type: :string, enum: Interview::STATUSES },
              notes: { type: :string, nullable: true }
            }
          },
          ApplicationContact: {
            type: :object, required: %w[id name role email phone notes],
            properties: {
              id: { type: :integer },
              name: { type: :string },
              role: { type: :string, nullable: true },
              email: { type: :string, nullable: true },
              phone: { type: :string, nullable: true },
              notes: { type: :string, nullable: true }
            }
          },
          ApplicationLink: {
            type: :object, required: %w[url],
            properties: { label: { type: :string, nullable: true, maxLength: 100 }, url: { type: :string, format: :uri } }
          },
          JobApplicationInput: {
            type: :object,
            properties: {
              applied_on: { type: :string, format: :date, nullable: true },
              next_action: { type: :string, nullable: true, maxLength: 200 },
              next_action_on: { type: :string, format: :date, nullable: true },
              notes: { type: :string, nullable: true, maxLength: JobApplication::NOTES_MAX_LENGTH },
              links: { type: :array, maxItems: JobApplication::MAX_LINKS, items: { "$ref" => "#/components/schemas/ApplicationLink" } }
            }
          },
          Requirement: {
            type: :object,
            required: %w[id kind text position],
            properties: {
              id: { type: :integer },
              kind: { type: :string, enum: Requirement::KINDS },
              text: { type: :string },
              position: { type: :integer, description: "Order within its kind, starting at 1" }
            }
          },
          JobPosting: {
            allOf: [
              { "$ref" => "#/components/schemas/JobPostingSummary" },
              {
                type: :object, required: %w[description requirements application employment_type seniority salary keywords extraction],
                properties: {
                  description: { type: :string },
                  employment_type: { type: :string, nullable: true },
                  seniority: { type: :string, nullable: true },
                  salary: { type: :string, nullable: true, description: "As stated in the ad" },
                  keywords: { type: :array, items: { type: :string } },
                  extraction: {
                    type: :object, required: %w[status error extracted_at],
                    properties: {
                      status: { type: :string, enum: JobPosting::EXTRACTION_STATUSES },
                      error: { type: :string, nullable: true },
                      extracted_at: { type: :string, format: "date-time", nullable: true }
                    }
                  },
                  requirements: { type: :array, items: { "$ref" => "#/components/schemas/Requirement" } },
                  application: { "$ref" => "#/components/schemas/JobApplication" }
                }
              }
            ]
          },
          JobPostingEnvelope: {
            type: :object, required: %w[job_posting],
            properties: { job_posting: { "$ref" => "#/components/schemas/JobPosting" } }
          },
          JobPostingInput: {
            type: :object,
            description: "title, company and description are required when creating.",
            properties: {
              title: { type: :string, maxLength: 200 },
              company: { type: :string, maxLength: 200 },
              location: { type: :string, maxLength: 200, nullable: true },
              work_model: { type: :string, enum: JobPosting::WORK_MODELS, nullable: true },
              employment_type: { type: :string, maxLength: 200, nullable: true },
              seniority: { type: :string, maxLength: 200, nullable: true },
              salary: { type: :string, maxLength: 200, nullable: true },
              deadline: { type: :string, format: :date, nullable: true },
              source_url: { type: :string, format: :uri, nullable: true },
              description: { type: :string, maxLength: JobPosting::DESCRIPTION_MAX_LENGTH, description: "The posting text" }
            }
          },
          Session: {
            type: :object,
            required: %w[id current created_at last_active_at],
            properties: {
              id: { type: :integer },
              current: { type: :boolean },
              ip_address: { type: :string, nullable: true },
              user_agent: { type: :string, nullable: true },
              created_at: { type: :string, format: "date-time" },
              last_active_at: { type: :string, format: "date-time" }
            }
          }
        }
      },
      servers: [
        { url: 'http://localhost:3000', description: 'Local development' }
      ]
    }
  }

  # Specify the format of the output Swagger file when running 'rswag:specs:swaggerize'.
  # The openapi_specs configuration option has the filename including format in
  # the key, this may want to be changed to avoid putting yaml in json files.
  # Defaults to json. Accepts ':json' and ':yaml'.
  config.openapi_format = :yaml
end

# Values for the documented security schemes. CSRF checks are off in tests and the
# session cookie comes from signing in, so these only satisfy rswag's parameter lookup.
RSpec.shared_context "rswag security" do
  let(:"X-CSRF-Token") { "not-checked-in-tests" }
  let(:evidex_session) { nil }
end

RSpec.configure do |config|
  config.include_context "rswag security", type: :request
end
