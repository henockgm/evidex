namespace :library do
  # Uses the configured queue (Solid Queue in production). In development the
  # :async adapter runs jobs inside the web server, so jobs queued from this
  # one-off process are lost; use `ProcessDocumentJob.perform_now(id)` there.
  desc "Queue text extraction for documents still waiting (e.g. uploaded before processing existed)"
  task process_pending: :environment do
    ids = Document.where(status: "pending").pluck(:id)
    ids.each { |id| ProcessDocumentJob.perform_later(id) }
    puts "Queued #{ids.size} document(s)."
  end
end
