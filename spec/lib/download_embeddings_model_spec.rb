require "rails_helper"

RSpec.describe "bin/download-embeddings-model" do
  it "downloads the model the app uses" do
    script = Rails.root.join("bin/download-embeddings-model").read

    expect(script).to include(%(MODEL = "#{Library::Embedder::Local::MODEL}"))
  end
end
