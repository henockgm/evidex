require "rails_helper"

RSpec.describe Library::Search do
  let(:user) { create(:user) }

  def library_doc(fixture, owner: user)
    create(:document, user: owner, fixture:).tap { |document| ProcessDocumentJob.perform_now(document.id) }
  end

  def search(query, as: user)
    described_class.new(as, query).call
  end

  before do
    library_doc("cv.pdf")
    library_doc("project.docx")
    library_doc("notes.md")
  end

  it "finds passages by words and by meaning, best first" do
    results = search("Solid Queue background jobs")

    expect(results.first.chunk.content).to include("Solid Queue background jobs")
    expect(results.first.matched_by).to contain_exactly(:semantic, :keyword)
    expect(results.map(&:score)).to eq(results.map(&:score).sort.reverse)
  end

  it "returns where each passage came from" do
    top = search("PostgreSQL RSpec Docker").first

    expect(top.chunk).to have_attributes(page: 2, section: "Skills")
    expect(top.chunk.document.title).to eq("My CV")
  end

  it "never returns other users' documents" do
    stranger = create(:user)
    library_doc("cv.pdf", owner: stranger)

    expect(search("Rails").map { |r| r.chunk.user_id }.uniq).to eq([ user.id ])
    expect(search("Rails", as: create(:user))).to be_empty
  end

  it "skips documents that aren't fully processed" do
    user.documents.update_all(status: "processing")
    expect(search("Rails")).to be_empty
  end

  it "handles empty and unusual queries" do
    expect(search("   ")).to eq([])
    expect { search(%q{"unbalanced OR -( quote')}) }.not_to raise_error
  end

  it "leaves out passages that are too far in meaning" do
    expect(search("zzz qqq xyzzy")).to be_empty
  end

  it "caps the number of results" do
    expect(described_class.new(user, "Rails", limit: 2).call.size).to eq(2)
  end
end
