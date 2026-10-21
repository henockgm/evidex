require "rails_helper"

RSpec.describe Library::TextExtractor do
  def extract(fixture)
    described_class.call(create(:document, fixture:).file.blob)
  end

  it "reads PDFs page by page" do
    pages = extract("cv.pdf")

    expect(pages.size).to eq(2)
    expect(pages.first).to include("Alex Example - Backend Developer", "Built REST APIs with Ruby on Rails and PostgreSQL.")
    expect(pages.last).to include("Ruby, Rails, PostgreSQL, RSpec, Docker")
  end

  it "reads Word documents, marking headings" do
    expect(extract("project.docx")).to eq([
      "# Project: Route planner API\nDesigned a route-planning API in Rails 8 with Solid Queue background jobs.\n" \
      "## Results\nCut planning time by half for 40 dispatchers."
    ])
  end

  it "reads Markdown and plain text as they are" do
    expect(extract("notes.md").first).to start_with("# Side projects\n\n## Evidex")
    expect(extract("notes.txt")).to eq([ "Certificates\n\nAWS Certified Developer - Associate, 2024" ])
  end

  it "explains when a PDF has no text layer" do
    expect { extract("scanned.pdf") }.to raise_error(described_class::Error, /No text found/)
  end

  it "refuses Word files that unpack to a huge size (zip bombs)" do
    expect { extract("bomb.docx") }.to raise_error(described_class::Error, /too large once unpacked/)
  end

  it "gives up on files that take too long to parse" do
    allow(PDF::Reader).to receive(:new) { sleep 5 }
    stub_const("#{described_class}::PARSE_TIMEOUT", 0.1)

    expect { extract("cv.pdf") }.to raise_error(described_class::Error, /took too long/)
  end

  it "caps very long documents" do
    stub_const("#{described_class}::MAX_CHARACTERS", 40)
    pages = extract("cv.pdf")
    expect(pages.sum(&:length)).to eq(40)
  end
end
