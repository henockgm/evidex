require "rails_helper"

RSpec.describe Requirement do
  let(:posting) { create(:job_posting) }

  it { is_expected.to validate_inclusion_of(:kind).in_array(Requirement::KINDS) }
  it { is_expected.to validate_presence_of(:text) }
  it { is_expected.to validate_length_of(:text).is_at_most(Requirement::TEXT_MAX_LENGTH) }

  it "numbers requirements within each kind in the order they're added" do
    first = create(:requirement, job_posting: posting, kind: "required")
    preferred = create(:requirement, job_posting: posting, kind: "preferred")
    second = create(:requirement, job_posting: posting, kind: "required")

    expect([ first.position, second.position, preferred.position ]).to eq([ 1, 2, 1 ])
    expect(posting.requirements.where(kind: "required")).to eq([ first, second ])
  end

  it "is deleted with its posting" do
    create(:requirement, job_posting: posting)
    expect { posting.destroy }.to change(described_class, :count).by(-1)
  end
end
