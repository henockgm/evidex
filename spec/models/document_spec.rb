require "rails_helper"

RSpec.describe Document do
  it "accepts PDF, Word, Markdown and plain text by their content" do
    %w[cv.pdf project.docx notes.md notes.txt].each do |fixture|
      expect(build(:document, fixture:)).to be_valid, fixture
    end
  end

  it "rejects a file whose content doesn't match an allowed type, whatever its extension" do
    document = build(:document, fixture: "fake.pdf")
    expect(document).not_to be_valid
    expect(document.errors[:file].join).to include("must be a PDF")
  end

  it "requires a file and rejects files over 10 MB" do
    expect(described_class.new(user: create(:user), title: "x")).not_to be_valid

    document = build(:document)
    allow(document.file.blob).to receive(:byte_size).and_return(Document::MAX_BYTES + 1)
    expect(document).not_to be_valid
    expect(document.errors[:file].join).to include("10 MB")
  end

  it "keeps one primary CV per user" do
    user = create(:user)
    first = create(:document, user:)
    second = create(:document, user:)

    first.make_primary!
    second.make_primary!

    expect([ first.reload.primary, second.reload.primary ]).to eq([ false, true ])
  end

  it "only lets CVs be primary" do
    expect(build(:document, kind: "certificate", primary: true)).not_to be_valid
  end

  it "deletes the stored file with the document and the user" do
    document = create(:document)
    blob_id = document.file.blob.id

    perform_enqueued_jobs { document.user.destroy }

    expect(described_class.exists?(document.id)).to be(false)
    expect(ActiveStorage::Blob.exists?(blob_id)).to be(false)
  end
end
