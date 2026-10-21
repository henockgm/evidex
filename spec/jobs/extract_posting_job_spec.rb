require "rails_helper"

RSpec.describe ExtractPostingJob, :ai do
  let(:posting) do
    create(:job_posting, title: "My own title", location: nil, work_model: nil, deadline: nil, extraction_status: "pending")
  end

  it "fills empty fields, keeps the user's, and adds only new requirements" do
    create(:requirement, job_posting: posting, kind: "required", text: "PostgreSQL")
    stub_claude(json: extraction_json)

    described_class.perform_now(posting.id)

    posting.reload
    expect(posting).to have_attributes(
      title: "My own title", location: "Helsinki", work_model: "hybrid", deadline: Date.new(2026, 11, 30),
      seniority: "Senior", salary: "€5,000–6,000 / month", keywords: %w[Ruby Rails PostgreSQL],
      extraction_status: "done", extraction_error: nil
    )
    expect(posting.extracted_at).to be_present
    expect(posting.requirements.where(kind: "required").pluck(:text)).to eq([ "PostgreSQL", "5+ years of Ruby on Rails" ])
    expect(posting.requirements.count).to eq(4)
  end

  it "records a readable failure" do
    stub_claude(json: {}, stop_reason: "refusal")

    described_class.perform_now(posting.id)

    expect(posting.reload).to have_attributes(extraction_status: "failed", extraction_error: "The AI declined to process this text")
  end

  it "does nothing unless extraction was requested" do
    posting.update!(extraction_status: "done")
    described_class.perform_now(posting.id)
    expect(a_request(:post, AnthropicHelpers::MESSAGES_URL)).not_to have_been_made
  end
end
