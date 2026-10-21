require "zip"

module Library
  # Pulls plain text out of an uploaded document, page by page for PDFs.
  # Uploaded files are untrusted: parsing is time-boxed and Word files are
  # checked for decompression bombs before anything is unpacked.
  class TextExtractor
    class Error < StandardError; end

    MAX_CHARACTERS = 500_000
    MAX_DOCX_XML_BYTES = 20.megabytes
    PARSE_TIMEOUT = 30 # seconds
    WORD_NS = { "w" => "http://schemas.openxmlformats.org/wordprocessingml/2006/main" }.freeze

    # Returns an array of page texts.
    def self.call(blob)
      new(blob).call
    end

    def initialize(blob)
      @blob = blob
    end

    def call
      pages = Timeout.timeout(PARSE_TIMEOUT) do
        @blob.open { |file| extract(file) }
      end
      pages = pages.map { |page| tidy(page) }
      raise Error, "No text found. Scanned PDFs (images of text) aren't supported yet." if pages.all?(&:blank?)

      limit(pages)
    rescue Timeout::Error
      raise Error, "Reading the file took too long"
    rescue PDF::Reader::MalformedPDFError, PDF::Reader::UnsupportedFeatureError, PDF::Reader::EncryptedPDFError => error
      raise Error, error.is_a?(PDF::Reader::EncryptedPDFError) ? "The PDF is password-protected" : "The PDF couldn't be read"
    rescue Zip::Error
      raise Error, "The Word file couldn't be read"
    end

    private
      def extract(file)
        case @blob.content_type
        when "application/pdf" then pdf_pages(file)
        when "application/vnd.openxmlformats-officedocument.wordprocessingml.document" then [ docx_text(file) ]
        when "text/markdown", "text/plain" then [ plain_text(file) ]
        else raise Error, "Unsupported file type"
        end
      end

      def pdf_pages(file)
        PDF::Reader.new(file.path).pages.map(&:text)
      end

      # Paragraphs on their own lines; headings marked with Markdown "#" so
      # chunking can split by section later.
      def docx_text(file)
        Zip::File.open(file.path) do |zip|
          entry = zip.find_entry("word/document.xml") or raise Error, "The Word file has no document body"
          raise Error, "The Word file is too large once unpacked" if entry.size > MAX_DOCX_XML_BYTES

          xml = Nokogiri::XML(entry.get_input_stream.read)
          xml.xpath("//w:body/w:p", WORD_NS).map { |paragraph| docx_paragraph(paragraph) }.join("\n")
        end
      end

      def docx_paragraph(paragraph)
        text = paragraph.xpath(".//w:t", WORD_NS).map(&:text).join
        style = paragraph.at_xpath("./w:pPr/w:pStyle/@w:val", WORD_NS)&.value.to_s
        level = style[/\AHeading(\d)\z/i, 1]
        level && text.present? ? "#{'#' * level.to_i} #{text}" : text
      end

      def plain_text(file)
        File.read(file.path, mode: "rb").force_encoding(Encoding::UTF_8).scrub("")
      end

      def tidy(text)
        text.to_s.gsub("\r\n", "\n").gsub(/[ \t ]+/, " ").gsub(/ *\n */, "\n").gsub(/\n{3,}/, "\n\n").strip
      end

      def limit(pages)
        remaining = MAX_CHARACTERS
        pages.filter_map do |page|
          next if remaining <= 0

          kept = page.first(remaining)
          remaining -= kept.length
          kept
        end
      end
  end
end
