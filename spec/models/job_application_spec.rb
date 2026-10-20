require "rails_helper"

RSpec.describe JobApplication do
  let(:posting) { create(:job_posting) }
  let(:application) { posting.job_application }

  it "is created as saved, with a first timeline event, when a posting is added" do
    expect(application).to have_attributes(status: "saved", user: posting.user)
    expect(application.events.map { |e| [ e.from_status, e.to_status ] }).to eq([ [ nil, "saved" ] ])
  end

  it "defines transitions for every status, only to known statuses" do
    expect(JobApplication::TRANSITIONS.values.flatten - JobApplication::STATUSES).to be_empty
  end

  it "moves through the pipeline and records each step with its note" do
    application.transition_to!("applied", note: "Sent via their portal")
    application.transition_to!("interviewing")

    expect(application.reload.status).to eq("interviewing")
    expect(application.events.map { |e| [ e.from_status, e.to_status, e.note ] }).to eq(
      [ [ nil, "saved", nil ], %w[saved applied Sent\ via\ their\ portal], [ "applied", "interviewing", nil ] ]
    )
  end

  it "refuses transitions that skip or reverse the pipeline" do
    expect { application.transition_to!("interviewing") }.to raise_error(JobApplication::InvalidTransition)
    application.transition_to!("withdrawn")
    expect { application.transition_to!("applied") }.to raise_error(JobApplication::InvalidTransition)
    expect(application.events.count).to eq(2)
  end

  it "treats rejected and withdrawn as final" do
    expect(JobApplication::TRANSITIONS.values_at("rejected", "withdrawn")).to all(be_empty)
  end

  it "is deleted, with its timeline, when the posting is" do
    application.transition_to!("applied")
    expect { posting.destroy }.to change(described_class, :count).by(-1).and change(JobApplicationEvent, :count).by(-2)
  end
end
