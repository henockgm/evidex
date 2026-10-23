require "rails_helper"

# ADM-03: admins operate the instance but can't read users' documents,
# postings, reports or applications.
RSpec.describe "Admins and users' content", type: :request do
  let(:admin) { create(:user, :admin) }
  let(:owner) { create(:user, email_address: "owner@example.com") }
  let(:secret) { "Confidential-#{SecureRandom.hex(4)}" }

  let!(:posting) { create(:job_posting, user: owner, title: "#{secret} role", description: "#{secret} description") }
  let!(:document) { create(:document, user: owner, title: "#{secret} CV") }
  let!(:report) do
    posting.match_reports.create!(user: owner, version: 1, status: "done", model: "claude-opus-5-5",
      strengths: [ "#{secret} strength" ], completed_at: Time.current)
  end

  before do
    posting.job_application.update!(notes: "#{secret} notes")
    AiUsage.create!(user: owner, feature: "match_report", model: "claude-opus-5-5", input_tokens: 10, output_tokens: 5)
    AuditEvent.create!(user: owner, action: "signed_in", metadata: { "method" => "password" })
    sign_in(admin)
  end

  it "gets 404 for another user's content, like any other user" do
    [
      "/api/v1/job_postings/#{posting.id}",
      "/api/v1/documents/#{document.id}",
      "/api/v1/documents/#{document.id}/text",
      "/api/v1/documents/#{document.id}/file",
      "/api/v1/match_reports/#{report.id}",
      "/api/v1/job_postings/#{posting.id}/match_report"
    ].each do |path|
      get path
      expect(response).to have_http_status(:not_found), "#{path} answered #{response.status}"
    end

    get "/api/v1/job_postings"
    expect(response.body).not_to include(secret)
    get "/api/v1/documents"
    expect(response.body).not_to include(secret)
  end

  it "never sees content in the admin area" do
    [
      "/api/v1/admin/overview",
      "/api/v1/admin/users",
      "/api/v1/admin/audit_events",
      "/api/v1/admin/ai_usage"
    ].each do |path|
      get path
      expect(response).to have_http_status(:ok)
      expect(response.body).not_to include(secret), "#{path} leaked user content"
    end
    expect(json["users"].pluck("user").pluck("email_address")).to include("owner@example.com")
  end
end
