require "rails_helper"

RSpec.describe ApplicationContact do
  subject(:contact) { build(:application_contact) }

  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_length_of(:name).is_at_most(100) }

  it "tidies its fields" do
    contact = described_class.new(name: "  Ana   Virtanen ", email: " Ana@Example.COM ", role: " ", phone: " +358  40 123 4567 ")
    expect(contact).to have_attributes(name: "Ana Virtanen", email: "ana@example.com", role: nil, phone: "+358 40 123 4567")
  end

  it "checks the email and phone formats" do
    contact.email = "not-an-email"
    contact.phone = "call me"
    expect(contact).not_to be_valid
    expect(contact.errors.attribute_names).to contain_exactly(:email, :phone)
  end

  it "is deleted with its application's posting" do
    contact.save!
    expect { contact.job_application.job_posting.destroy }.to change(described_class, :count).by(-1)
  end
end
