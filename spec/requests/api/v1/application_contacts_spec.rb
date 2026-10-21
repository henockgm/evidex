require "swagger_helper"

RSpec.describe "Application contacts API", type: :request do
  let(:user) { create(:user) }
  let(:application) { create(:job_posting, user:).job_application }

  before { sign_in(user) }

  contact_input = {
    type: :object,
    properties: {
      name: { type: :string, maxLength: 100 },
      role: { type: :string, nullable: true, maxLength: 100 },
      email: { type: :string, format: :email, nullable: true },
      phone: { type: :string, nullable: true, maxLength: 40 },
      notes: { type: :string, nullable: true, maxLength: 2000 }
    }
  }

  path "/api/v1/job_applications/{job_application_id}/contacts" do
    parameter name: :job_application_id, in: :path, type: :integer

    post "Add a contact to an application" do
      tags "Applications"
      consumes "application/json"
      produces "application/json"
      security [ { session_cookie: [], csrf_token: [] } ]
      parameter name: :body, in: :body, schema: { type: :object, required: %w[contact], properties: { contact: contact_input.merge(required: %w[name]) } }

      let(:job_application_id) { application.id }

      response "201", "added" do
        schema type: :object, required: %w[contact], properties: { contact: { "$ref" => "#/components/schemas/ApplicationContact" } }
        let(:body) { { contact: { name: "Ana Virtanen", role: "Recruiter", email: "Ana@Example.com" } } }

        run_test! do
          expect(application.contacts.sole).to have_attributes(name: "Ana Virtanen", email: "ana@example.com")
        end
      end

      response "422", "invalid" do
        schema "$ref" => "#/components/schemas/Problem"
        let(:body) { { contact: { name: "", email: "nope" } } }
        run_test!
      end

      response "404", "someone else's application" do
        schema "$ref" => "#/components/schemas/Problem"
        let(:job_application_id) { create(:job_posting).job_application.id }
        let(:body) { { contact: { name: "Planted" } } }

        run_test! do
          expect(ApplicationContact.count).to eq(0)
        end
      end
    end
  end

  path "/api/v1/contacts/{id}" do
    parameter name: :id, in: :path, type: :integer

    patch "Update a contact" do
      tags "Applications"
      consumes "application/json"
      produces "application/json"
      security [ { session_cookie: [], csrf_token: [] } ]
      parameter name: :body, in: :body, schema: { type: :object, required: %w[contact], properties: { contact: contact_input } }

      let(:contact) { create(:application_contact, job_application: application) }
      let(:id) { contact.id }

      response "200", "updated" do
        schema type: :object, required: %w[contact], properties: { contact: { "$ref" => "#/components/schemas/ApplicationContact" } }
        let(:body) { { contact: { role: "Hiring manager", phone: "+358 40 123 4567" } } }

        run_test! do
          expect(contact.reload).to have_attributes(role: "Hiring manager", phone: "+358 40 123 4567", name: "Ana Virtanen")
        end
      end

      response "404", "someone else's contact" do
        schema "$ref" => "#/components/schemas/Problem"
        let(:id) { create(:application_contact).id }
        let(:body) { { contact: { name: "Changed" } } }

        run_test! do
          expect(ApplicationContact.find(id).name).to eq("Ana Virtanen")
        end
      end
    end

    delete "Remove a contact" do
      tags "Applications"
      security [ { session_cookie: [], csrf_token: [] } ]

      response "204", "removed" do
        let(:id) { create(:application_contact, job_application: application).id }

        run_test! do
          expect(ApplicationContact.exists?(id)).to be(false)
        end
      end

      response "404", "someone else's contact" do
        schema "$ref" => "#/components/schemas/Problem"
        let(:id) { create(:application_contact).id }
        run_test!
      end
    end
  end

  it "lists contacts in the posting's application" do
    create(:application_contact, job_application: application, name: "Ana")
    get "/api/v1/job_postings/#{application.job_posting_id}"
    expect(json["job_posting"]["application"]["contacts"].pluck("name")).to eq([ "Ana" ])
  end
end
