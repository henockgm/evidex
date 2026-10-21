require "rails_helper"

RSpec.describe Library::Embedder do
  it "uses the fake backend in tests" do
    expect(described_class.model_name).to eq("fake")
  end

  it "returns normalised vectors of the configured size, closer for shared words" do
    rails, also_rails, baking = described_class.embed_passages([ "Ruby on Rails APIs", "Rails APIs with Ruby", "Baking bread" ])
    dot = ->(a, b) { a.zip(b).sum { |x, y| x * y } }

    expect(rails.size).to eq(Library::Embedder::DIMENSIONS)
    expect(dot.(rails, rails)).to be_within(1e-9).of(1.0)
    expect(dot.(rails, also_rails)).to be > dot.(rails, baking)
  end

  it "adds the e5 prefixes and batches when running the local model" do
    pipeline = instance_double(Proc)
    allow(Informers).to receive(:pipeline).with("embedding", "Xenova/multilingual-e5-small", quantized: true).and_return(pipeline)
    allow(pipeline).to receive(:call) { |inputs| inputs.map { [ 0.0 ] * Library::Embedder::DIMENSIONS } }
    local = Library::Embedder::Local.new

    local.embed_passages(Array.new(20) { |i| "text #{i}" })
    local.embed_query("APIs")

    expect(pipeline).to have_received(:call).with(array_including("passage: text 0")).once
    expect(pipeline).to have_received(:call).with(array_including("passage: text 19")).once
    expect(pipeline).to have_received(:call).with([ "query: APIs" ])
  end
end
