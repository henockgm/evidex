require "rails_helper"

RSpec.describe ProcessDocumentJob do
  it "is queued when a document is uploaded" do
    document = create(:document)
    expect(described_class).to have_been_enqueued.with(document.id)
  end

  it "stores the text and marks the document ready" do
    document = create(:document)

    described_class.perform_now(document.id)

    expect(document.reload).to have_attributes(status: "ready", error: nil)
    expect(document.text_pages.size).to eq(2)
    expect(document.character_count).to eq(document.text_pages.sum(&:length))
    expect(document.processed_at).to be_present
    expect(document.chunks.map { |c| [ c.page, c.section, c.user_id ] }).to eq([ [ 1, "Experience", document.user_id ], [ 2, "Skills", document.user_id ], [ 2, "Education", document.user_id ] ])
  end

  it "replaces old chunks when a document is read again" do
    document = create(:document, fixture: "notes.md")
    described_class.perform_now(document.id)
    document.update_columns(status: "pending")

    expect { described_class.perform_now(document.id) }.not_to change { document.chunks.count }
  end

  it "marks failures with a readable reason, and can be retried" do
    document = create(:document, fixture: "scanned.pdf")

    described_class.perform_now(document.id)
    expect(document.reload).to have_attributes(status: "failed", error: a_string_including("No text found"))

    expect { document.retry_processing! }.to have_enqueued_job(described_class).with(document.id)
    expect(document.reload).to have_attributes(status: "pending", error: nil)
  end

  it "skips documents that aren't waiting" do
    document = create(:document)
    document.update_columns(status: "ready")

    expect(Library::TextExtractor).not_to receive(:call)
    described_class.perform_now(document.id)
  end
end
