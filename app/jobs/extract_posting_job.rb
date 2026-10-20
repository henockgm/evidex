class ExtractPostingJob < ApplicationJob
  queue_as :default
  discard_on ActiveRecord::RecordNotFound

  def perform(job_posting_id)
    posting = JobPosting.find(job_posting_id)
    return unless posting.extraction_status == "pending"

    result = Ai::PostingExtractor.new(posting).call
    posting.apply_extraction!(result)
  rescue Ai::Client::Error => error
    posting&.update_columns(extraction_status: "failed", extraction_error: error.message.first(255), updated_at: Time.current)
  end
end
