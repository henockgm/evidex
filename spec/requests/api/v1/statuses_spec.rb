require "swagger_helper"

RSpec.describe "API status", type: :request do
  path "/api/v1/status" do
    get "Returns API and database status" do
      tags "Status"
      produces "application/json"

      response "200", "API is up" do
        schema type: :object,
          required: %w[name api_version environment database time],
          properties: {
            name: { type: :string, example: "Evidex" },
            api_version: { type: :string, example: "v1" },
            environment: { type: :string },
            database: { type: :string, enum: %w[ok error] },
            time: { type: :string, format: "date-time" }
          }

        run_test! do |response|
          body = response.parsed_body
          expect(body["name"]).to eq("Evidex")
          expect(body["database"]).to eq("ok")
        end
      end
    end
  end
end
