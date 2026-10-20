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
            required: %w[id email_address email_verified has_password identities created_at],
            properties: {
              id: { type: :integer },
              email_address: { type: :string, format: :email },
              name: { type: :string, nullable: true },
              email_verified: { type: :boolean },
              has_password: { type: :boolean },
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
            required: %w[id status available_transitions applied_on next_action next_action_on notes links events],
            properties: {
              id: { type: :integer },
              status: { "$ref" => "#/components/schemas/ApplicationStatus" },
              applied_on: { type: :string, format: :date, nullable: true },
              next_action: { type: :string, nullable: true },
              next_action_on: { type: :string, format: :date, nullable: true },
              notes: { type: :string, nullable: true },
              links: { type: :array, items: { "$ref" => "#/components/schemas/ApplicationLink" } },
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
                type: :object, required: %w[description requirements application],
                properties: {
                  description: { type: :string },
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
