module Library
  # Splits a document's pages into passages of a few paragraphs (~300 tokens),
  # remembering the page and the nearest heading, so matches can be cited
  # precisely. Neighbouring chunks share a short paragraph of overlap.
  class Chunker
    Chunk = Data.define(:page, :section, :content)

    TARGET_CHARS = 1_200   # ~300 tokens
    MAX_CHARS = 2_000
    OVERLAP_MAX_CHARS = 300

    MARKDOWN_HEADING = /\A\#{1,6}\s+(?<title>.+)\z/
    BULLET = /\A[-*•▪◦]\s/

    # pages: array of page texts. paginated: true for PDFs (page numbers are kept).
    def self.call(pages, paginated:)
      new(pages, paginated:).call
    end

    def initialize(pages, paginated:)
      @pages = pages
      @paginated = paginated
    end

    def call
      chunks = []
      section = nil

      @pages.each_with_index do |text, index|
        page = @paginated ? index + 1 : nil
        paragraphs = []

        blocks(text).each do |block|
          if (title = heading(block))
            if paragraphs == [ section ]
              # Two headings in a row, e.g. a name line then "Experience", or
              # "Education" then a degree: the shorter, more generic one names
              # the section, and both stay in the text.
              paragraphs << title
              section = title if title.split.size <= section.split.size
            else
              chunks.concat(pack(paragraphs, page, section))
              paragraphs = [ title ] # the heading stays in the text too
              section = title
            end
          else
            paragraphs.concat(split_long(block))
          end
        end
        chunks.concat(pack(paragraphs, page, section))
      end

      chunks
    end

    private
      # Paragraphs separated by blank lines; a heading line starts its own block.
      def blocks(text)
        result = []
        current = []
        text.to_s.each_line(chomp: true) do |line|
          line = line.strip
          if line.empty?
            result << current.join("\n") if current.any?
            current = []
          elsif heading(line) && (current.empty? || !heading(current.last))
            result << current.join("\n") if current.any?
            result << line
            current = []
          else
            current << line
          end
        end
        result << current.join("\n") if current.any?
        result
      end

      # Markdown headings, or short title-like lines ("Experience", "Skills:")
      # as found in PDFs, where headings aren't marked.
      def heading(block)
        return nil if block.include?("\n")
        return Regexp.last_match[:title].strip if block.match(MARKDOWN_HEADING)

        line = block.delete_suffix(":")
        title_like = line.length.between?(3, 50) && line.split.size <= 6 && line.match?(/\A\p{Lu}/) &&
          !line.match?(/[.,;!?]/) && !line.match?(/\d/) && !line.match?(BULLET)
        title_like ? line : nil
      end

      def pack(paragraphs, page, section)
        chunks = []
        current = []

        paragraphs.each do |paragraph|
          if current.any? && length(current + [ paragraph ]) > TARGET_CHARS
            chunks << Chunk.new(page:, section:, content: current.join("\n\n"))
            last = current.last
            current = current.size > 1 && last.length <= OVERLAP_MAX_CHARS ? [ last ] : []
          end
          current << paragraph
        end
        chunks << Chunk.new(page:, section:, content: current.join("\n\n")) if current.any? && current != [ section ]
        chunks
      end

      def length(paragraphs)
        paragraphs.sum(&:length) + 2 * (paragraphs.size - 1)
      end

      # Over-long paragraphs are cut at sentence ends, or hard-cut as a last resort.
      def split_long(paragraph)
        return [ paragraph ] if paragraph.length <= MAX_CHARS

        pieces = []
        current = +""
        paragraph.split(/(?<=[.!?])\s+/).each do |sentence|
          sentence.scan(/.{1,#{MAX_CHARS}}/m).each do |part|
            if current.length + part.length + 1 > MAX_CHARS && current.present?
              pieces << current
              current = +""
            end
            current << (current.empty? ? part : " #{part}")
          end
        end
        pieces << current if current.present?
        pieces
      end
  end
end
