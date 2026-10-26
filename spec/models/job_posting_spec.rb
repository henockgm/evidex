require "rails_helper"

RSpec.describe JobPosting do
  subject(:posting) { build(:job_posting) }

  it { is_expected.to belong_to(:user) }
  it { is_expected.to validate_presence_of(:title) }
  it { is_expected.to validate_presence_of(:company) }
  it { is_expected.to validate_presence_of(:description) }
  it { is_expected.to validate_length_of(:description).is_at_most(JobPosting::DESCRIPTION_MAX_LENGTH) }
  it { is_expected.to validate_inclusion_of(:work_model).in_array(JobPosting::WORK_MODELS).allow_nil }

  it "tidies whitespace and turns blank optional fields into nil" do
    posting = described_class.new(title: "  Rails   Developer ", location: "  ", work_model: "", source_url: " ")

    expect(posting).to have_attributes(title: "Rails Developer", location: nil, work_model: nil, source_url: nil)
  end

  it "accepts only http and https links" do
    posting.source_url = "javascript:alert(1)"
    expect(posting).not_to be_valid
    expect(posting.errors[:source_url]).to include("must be an http or https link")

    posting.source_url = "https://example.com/jobs/1"
    expect(posting).to be_valid
  end

  it "stores the link in comparable form" do
    posting.update!(source_url: "https://Jobs.Example.com/rails/?utm_source=x")
    expect(posting.normalized_source_url).to eq("https://jobs.example.com/rails")

    posting.update!(source_url: nil)
    expect(posting.normalized_source_url).to be_nil
  end

  describe "#possible_duplicates" do
    let(:user) { create(:user) }
    let!(:first) { create(:job_posting, user:, source_url: "https://jobs.example.com/rails") }

    it "finds the user's other postings for the same ad" do
      posting = build(:job_posting, user:, source_url: "https://jobs.example.com/rails/?utm_medium=feed#top")
      expect(posting.possible_duplicates).to eq([ first ])
    end

    it "doesn't match the posting itself, other ads, other users or postings without a link" do
      create(:job_posting, user:, source_url: "https://jobs.example.com/rails-2")
      create(:job_posting, source_url: "https://jobs.example.com/rails")
      create(:job_posting, user:, source_url: nil)

      expect(first.possible_duplicates).to be_empty
      expect(build(:job_posting, user:, source_url: nil).possible_duplicates).to be_empty
    end
  end

  it "is deleted with its user" do
    posting.save!
    expect { posting.user.destroy }.to change(described_class, :count).by(-1)
  end
end
