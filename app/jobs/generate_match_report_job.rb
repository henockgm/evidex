class GenerateMatchReportJob < ApplicationJob
  queue_as :default
  discard_on ActiveRecord::RecordNotFound

  def perform(report_id)
    report = MatchReport.find(report_id)
    return unless report.status == "pending"

    report.update!(status: "running")
    Matching::ReportGenerator.new(report).call
  rescue Ai::Client::Error => error
    report&.update_columns(status: "failed", error: error.message.first(255), updated_at: Time.current)
  end
end
