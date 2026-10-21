require "rails_helper"
require "rake"

RSpec.describe "library:process_pending" do
  before(:all) { Rails.application.load_tasks if Rake::Task.tasks.empty? }

  it "queues every document still waiting" do
    waiting = create(:document)
    done = create(:document).tap { |d| d.update_columns(status: "ready") }
    clear_enqueued_jobs

    expect { Rake::Task["library:process_pending"].execute }.to output(/Queued 1 document/).to_stdout
    expect(ProcessDocumentJob).to have_been_enqueued.with(waiting.id)
    expect(ProcessDocumentJob).not_to have_been_enqueued.with(done.id)
  end
end
