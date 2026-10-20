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

  it "is deleted with its user" do
    posting.save!
    expect { posting.user.destroy }.to change(described_class, :count).by(-1)
  end
end
