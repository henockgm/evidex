require "rails_helper"

RSpec.describe Interview do
  subject(:interview) { build(:interview) }

  it { is_expected.to validate_presence_of(:scheduled_at) }
  it { is_expected.to validate_inclusion_of(:format).in_array(Interview::FORMATS).allow_nil }
  it { is_expected.to validate_inclusion_of(:status).in_array(Interview::STATUSES) }

  it "defaults to scheduled and tidies text" do
    interview = described_class.new(round: "  Technical   round ", location: " ", format: " ")
    expect(interview).to have_attributes(status: "scheduled", round: "Technical round", location: nil, format: nil)
  end

  it "lists only scheduled interviews that haven't happened yet as upcoming" do
    upcoming = create(:interview)
    create(:interview, scheduled_at: 1.day.ago)
    create(:interview, status: "cancelled")

    expect(described_class.upcoming).to eq([ upcoming ])
  end
end
