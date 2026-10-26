module Demo
  # The shared demo account visitors can try without signing up. Its data is
  # fictional and rebuilt from db/demo by reset! (daily and on demand), so
  # whatever visitors change is gone the next day. The saved match report is
  # restored from a file, so a reset never calls the AI.
  class Account
    EMAIL = "demo@evidex.invalid".freeze
    NAME = "Alex Example".freeze
    DATA = Rails.root.join("db/demo")
    DOCUMENTS = [
      { file: "cv.md", title: "Alex Example – CV", kind: "cv", primary: true },
      { file: "projects.md", title: "Alex Example – Selected projects", kind: "project" }
    ].freeze

    def self.user
      User.find_by(demo: true)
    end

    def self.reset!
      new.reset!
    end

    # Not one transaction: Active Storage stores a file only after its record is
    # committed, and the documents have to be read before the report is restored.
    def reset!
      user = User.find_or_create_by!(demo: true) do |new_user|
        new_user.email_address = EMAIL
        new_user.name = NAME
        new_user.email_verified_at = Time.current
      end
      user.job_postings.destroy_all
      user.documents.destroy_all
      documents = DOCUMENTS.map { |spec| add_document(user, spec) }
      postings = YAML.load_file(DATA.join("postings.yml")).map { |spec| add_posting(user, spec) }
      restore_match_report(postings.first, documents)
      user
    end

    private
      def add_document(user, spec)
        document = user.documents.create!(
          title: spec[:title], kind: spec[:kind], primary: spec.fetch(:primary, false), status: "processing",
          file: { io: DATA.join(spec[:file]).open, filename: spec[:file], content_type: "text/markdown" }
        )
        # Read and embed it now (locally, no AI call) so the report's citations can point at chunks.
        # Created as "processing", so the job queued on create leaves it alone.
        ProcessDocumentJob.process(document)
        document.reload
      end

      def add_posting(user, spec)
        posting = user.job_postings.create!(
          spec.slice("title", "company", "location", "work_model", "employment_type", "seniority", "source_url",
            "keywords", "description").merge("deadline" => spec["deadline_in_days"]&.days&.from_now&.to_date)
        )
        spec.fetch("requirements", {}).each do |kind, texts|
          texts.each { |text| posting.requirements.create!(kind:, text:) }
        end
        progress_application(posting.job_application, spec.fetch("application", {}))
        posting
      end

      def progress_application(application, spec)
        spec.fetch("statuses", []).each { |status| application.transition_to!(status) }
        application.update!(
          applied_on: spec["applied_days_ago"]&.days&.ago&.to_date,
          next_action: spec["next_action"],
          next_action_on: spec["next_action_in_days"]&.days&.from_now&.to_date,
          notes: spec["notes"]
        )
        spec.fetch("contacts", []).each { |contact| application.contacts.create!(contact) }
        spec.fetch("interviews", []).each do |interview|
          application.interviews.create!(interview.except("in_days").merge(
            "scheduled_at" => interview["in_days"].days.from_now.change(hour: 13), "status" => "scheduled"
          ))
        end
      end

      def restore_match_report(posting, documents)
        path = DATA.join("match_report.yml")
        return unless path.exist?

        saved = YAML.load_file(path)
        report = posting.match_reports.create!(
          user: posting.user, version: 1, status: "done", model: saved["model"],
          strengths: saved["strengths"], gaps: saved["gaps"], completed_at: Time.current
        )
        saved["matches"].each_with_index do |match, index|
          requirement = posting.requirements.find_by(kind: match["kind"], text: match["text"])
          requirement_match = report.matches.create!(
            requirement:, requirement_kind: match["kind"], requirement_text: match["text"],
            verdict: match["verdict"], reasoning: match["reasoning"], position: index
          )
          match.fetch("citations", []).each do |citation|
            document = documents.find { |doc| doc.file.filename.to_s == citation["document"] }
            chunk = document&.chunks&.find { |candidate| candidate.content.include?(citation["passage_starts_with"]) }
            next unless chunk

            requirement_match.citations.create!(
              document_chunk: chunk, document:, document_title: document.title, page: chunk.page,
              section: chunk.section, excerpt: chunk.content.first(Matching::ReportGenerator::EXCERPT_LENGTH)
            )
          end
        end
      end
  end
end
