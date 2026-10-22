require "rails_helper"

RSpec.describe GenerateMatchReportJob, :ai do
  let(:posting) { create(:job_posting) }
  let(:report) { posting.match_reports.create!(user: posting.user, version: 1) }

  before do
    create(:requirement, job_posting: posting, text: "Rails")
    create(:document, user: posting.user).tap { |document| ProcessDocumentJob.perform_now(document.id) }
  end

  it "runs the generator" do
    stub_claude(json: { matches: [], strengths: [], gaps: [] })
    described_class.perform_now(report.id)
    expect(report.reload.status).to eq("done")
  end

  it "records a readable failure" do
    stub_claude(json: {}, stop_reason: "refusal")
    described_class.perform_now(report.id)
    expect(report.reload).to have_attributes(status: "failed", error: "The AI declined to process this text")
  end

  it "only runs pending reports" do
    report.update!(status: "done")
    expect(Matching::ReportGenerator).not_to receive(:new)
    described_class.perform_now(report.id)
  end
end
