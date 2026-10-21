require "rails_helper"

RSpec.describe Library::Chunker do
  def chunk(pages, paginated: false)
    described_class.call(pages, paginated:).map(&:to_h)
  end

  it "splits by Markdown headings and keeps the heading as the section" do
    text = "# Side projects\n\n## Evidex\n\nA Rails API that matches job requirements.\n\n## Tooling\n\nWrote CLI tools in Ruby."

    expect(chunk([ text ])).to eq([
      { page: nil, section: "Evidex", content: "Side projects\n\nEvidex\n\nA Rails API that matches job requirements." },
      { page: nil, section: "Tooling", content: "Tooling\n\nWrote CLI tools in Ruby." }
    ])
  end

  it "recognises title-like lines as headings in PDFs and keeps page numbers" do
    pages = [
      "Alex Example - Backend Developer\nExperience\nAcme Oy, Rails developer, 2021-2025\nBuilt REST APIs with Ruby on Rails.",
      "Skills\nRuby, Rails, PostgreSQL"
    ]

    expect(chunk(pages, paginated: true)).to eq([
      { page: 1, section: "Experience",
        content: "Alex Example - Backend Developer\n\nExperience\n\nAcme Oy, Rails developer, 2021-2025\nBuilt REST APIs with Ruby on Rails." },
      { page: 2, section: "Skills", content: "Skills\n\nRuby, Rails, PostgreSQL" }
    ])
  end

  it "names a section after the more generic of two consecutive headings" do
    expect(chunk([ "Education\nBSc Computer Science\nUniversity of Tampere, 2018" ]).sole[:section]).to eq("Education")
  end

  it "carries a section over to the next page" do
    pages = [ "Experience\nAcme Oy, developer, 2021", "Beta Ltd, consultant, 2019" ]
    expect(chunk(pages, paginated: true).map { |c| [ c[:page], c[:section] ] }).to eq([ [ 1, "Experience" ], [ 2, "Experience" ] ])
  end

  it "doesn't treat sentences, bullets or dated lines as headings" do
    text = "Built APIs.\n- Ruby\nAcme Oy 2021"
    expect(chunk([ text ]).sole[:section]).to be_nil
  end

  it "packs paragraphs up to the target size with a short overlap" do
    paragraphs = Array.new(6) { |i| "Paragraph #{i} " + ("x" * 280) + "." }
    chunks = chunk([ paragraphs.join("\n\n") ])

    expect(chunks.size).to be > 1
    expect(chunks.map { |c| c[:content].length }).to all(be <= described_class::TARGET_CHARS + 300)
    expect(chunks[1][:content]).to start_with(chunks[0][:content].split("\n\n").last)
  end

  it "cuts over-long paragraphs at sentence ends" do
    long = Array.new(60) { |i| "Sentence number #{i} about Rails and PostgreSQL work." }.join(" ")
    chunks = chunk([ long ])

    expect(chunks.map { |c| c[:content].length }).to all(be <= described_class::MAX_CHARS)
    expect(chunks.map { |c| c[:content] }.join(" ").scan("Sentence number").size).to be >= 60
  end

  it "returns nothing for empty text" do
    expect(chunk([ "", "  " ])).to eq([])
  end
end
