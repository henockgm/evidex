require "rails_helper"

RSpec.describe "pgvector extension" do
  it "is enabled in the database" do
    expect(ActiveRecord::Base.connection.extension_enabled?("vector")).to be(true)
  end
end
