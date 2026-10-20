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

  it "records the applied date when moving to applied, keeping one the user already set" do
    travel_to Date.new(2026, 10, 20) do
      application.transition_to!("applied")
      expect(application.applied_on).to eq(Date.new(2026, 10, 20))
    end

    other = create(:job_posting).job_application
    other.update!(applied_on: Date.new(2026, 10, 1))
    other.transition_to!("applied")
    expect(other.applied_on).to eq(Date.new(2026, 10, 1))
  end

  describe "links" do
    it "keeps label/url pairs, trimmed, and drops empty rows" do
      application.update!(links: [ { label: " Portal ", url: " https://jobs.example.com/a ", extra: "x" }, { label: "", url: "" } ])
      expect(application.links).to eq([ { "label" => "Portal", "url" => "https://jobs.example.com/a" } ])
    end

    it "accepts only http(s) links" do
      application.links = [ { label: "Bad", url: "javascript:alert(1)" } ]
      expect(application).not_to be_valid
      expect(application.errors[:links].join).to include("http or https")
    end

    it "needs a url for every label" do
      application.links = [ { label: "Recruiter's LinkedIn", url: "" } ]
      expect(application).not_to be_valid
    end

    it "limits the number of links" do
      application.links = Array.new(JobApplication::MAX_LINKS + 1) { |i| { url: "https://example.com/#{i}" } }
      expect(application).not_to be_valid
    end
  end
end
