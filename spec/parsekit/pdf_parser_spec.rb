# frozen_string_literal: true

RSpec.describe "PDF Parsing with MuPDF" do
  let(:parser) { ParseKit::Parser.new }

  # Generate a minimal but structurally valid PDF with correct xref byte offsets.
  # Hand-crafted heredoc PDFs with hardcoded offsets fail on MuPDF >= 0.8.0 because
  # the newer library is stricter about xref validation. This helper computes offsets
  # from the actual byte positions so the result is always a well-formed PDF.
  def generate_minimal_pdf(text)
    header  = "%PDF-1.4\n"
    obj1    = "1 0 obj\n<< /Type /Catalog /Pages 2 0 R >>\nendobj\n"
    obj2    = "2 0 obj\n<< /Type /Pages /Kids [3 0 R] /Count 1 >>\nendobj\n"
    obj3    = "3 0 obj\n<< /Type /Page /Parent 2 0 R /Resources << /Font << /F1 4 0 R >> >> /MediaBox [0 0 612 792] /Contents 5 0 R >>\nendobj\n"
    obj4    = "4 0 obj\n<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica >>\nendobj\n"
    stream  = "BT\n/F1 12 Tf\n100 700 Td\n(#{text}) Tj\nET\n"
    obj5    = "5 0 obj\n<< /Length #{stream.bytesize} >>\nstream\n#{stream}endstream\nendobj\n"

    offsets = []
    pos = header.bytesize
    [obj1, obj2, obj3, obj4].each { |o| offsets << pos; pos += o.bytesize }
    offsets << pos
    xref_pos = pos + obj5.bytesize

    xref    = "xref\n0 6\n0000000000 65535 f \n"
    offsets.each { |o| xref += "%010d 00000 n \n" % o }
    trailer = "trailer\n<< /Size 6 /Root 1 0 R >>\nstartxref\n#{xref_pos}\n%%EOF\n"

    header + obj1 + obj2 + obj3 + obj4 + obj5 + xref + trailer
  end

  describe "#parse_pdf" do
    context "with valid PDF data" do
      # Use the sample.pdf fixture: hand-crafted minimal PDFs (Helvetica Type1 without
      # embedded encoding) stopped yielding extractable text in MuPDF >= 0.8.0 (mupdf
      # C lib 1.27.2). sample.pdf is a proper PDF that works across all versions.
      let(:simple_pdf) do
        File.read(File.join(__dir__, "..", "fixtures", "sample.pdf"), mode: "rb").bytes
      end

      it "extracts text from PDF" do
        result = parser.parse_pdf(simple_pdf)
        expect(result).to be_a(String)
        expect(result).to include("PDF document for testing")
      end
    end

    context "with empty PDF" do
      let(:empty_pdf) do
        # Minimal valid PDF structure without text content
        pdf_content = <<~PDF
          %PDF-1.4
          1 0 obj
          << /Type /Catalog /Pages 2 0 R >>
          endobj
          2 0 obj
          << /Type /Pages /Kids [] /Count 0 >>
          endobj
          xref
          0 3
          0000000000 65535 f
          0000000009 00000 n
          0000000062 00000 n
          trailer
          << /Size 3 /Root 1 0 R >>
          startxref
          120
          %%EOF
        PDF
        pdf_content.bytes
      end

      it "returns appropriate message for PDF with no text" do
        result = parser.parse_pdf(empty_pdf)
        expect(result).to include("no extractable text")
      end
    end

    context "with invalid PDF data" do
      it "raises error for invalid PDF structure" do
        invalid_data = "Not a PDF file".bytes
        expect { parser.parse_pdf(invalid_data) }.to raise_error(RuntimeError, /Failed to parse PDF/)
      end

      it "raises error for corrupted PDF header" do
        corrupted_pdf = "%PDF-1.corrupted".bytes
        expect { parser.parse_pdf(corrupted_pdf) }.to raise_error(RuntimeError, /Failed to parse PDF/)
      end
    end

    context "with real PDF file" do
      it "parses a real PDF file" do
        # Use the sample.pdf fixture that already exists
        pdf_fixture = File.join(__dir__, "..", "fixtures", "sample.pdf")
        
        if File.exist?(pdf_fixture)
          pdf_data = File.read(pdf_fixture, mode: 'rb').bytes
          result = parser.parse_pdf(pdf_data)
          expect(result).to be_a(String)
          expect(result).not_to be_empty
          # The actual content will depend on what's in sample.pdf
          expect(result.length).to be > 10
        else
          # Create a minimal valid PDF if fixture doesn't exist
          minimal_pdf = [
            "%PDF-1.4",
            "1 0 obj<</Type/Catalog/Pages 2 0 R>>endobj",
            "2 0 obj<</Type/Pages/Count 1/Kids[3 0 R]>>endobj",
            "3 0 obj<</Type/Page/Parent 2 0 R/MediaBox[0 0 612 792]/Contents 4 0 R>>endobj",
            "4 0 obj<</Length 44>>stream",
            "BT /F1 12 Tf 100 700 Td (Test PDF Content) Tj ET",
            "endstream endobj",
            "xref",
            "0 5",
            "0000000000 65535 f",
            "0000000009 00000 n",
            "0000000056 00000 n",
            "0000000108 00000 n",
            "0000000201 00000 n",
            "trailer<</Size 5/Root 1 0 R>>",
            "startxref",
            "291",
            "%%EOF"
          ].join("\n")
          
          pdf_data = minimal_pdf.bytes
          result = parser.parse_pdf(pdf_data)
          expect(result).to be_a(String)
          # Minimal PDF might not have extractable text
          expect(result).to match(/no extractable text|Test PDF Content/i)
        end
      end
    end
  end

  describe "#parse_file with PDF" do
    require 'tmpdir'
    let(:temp_dir) { Dir.mktmpdir }
    let(:test_pdf_path) { File.join(temp_dir, "test.pdf") }

    before do
      # Copy sample.pdf fixture rather than generating a hand-crafted PDF.
      # Hand-crafted minimal PDFs (Helvetica Type1 without embedded encoding) stopped
      # yielding extractable text in MuPDF >= 0.8.0 (mupdf C lib 1.27.2).
      FileUtils.cp(
        File.join(__dir__, "..", "fixtures", "sample.pdf"),
        test_pdf_path
      )
    end

    after do
      FileUtils.rm_rf(temp_dir) if Dir.exist?(temp_dir)
    end

    it "automatically detects and parses PDF files" do
      result = parser.parse_file(test_pdf_path)
      expect(result).to include("PDF document for testing")
    end
  end

  describe "#parse_bytes with PDF auto-detection" do
    it "detects PDF from magic bytes and parses correctly" do
      # Use sample.pdf fixture: minimal hand-crafted PDFs stopped yielding text in MuPDF >= 0.8.0.
      pdf_bytes = File.read(File.join(__dir__, "..", "fixtures", "sample.pdf"), mode: "rb").bytes
      result = parser.parse_bytes(pdf_bytes)
      expect(result).to include("PDF document for testing")
    end
  end

  describe "PDF support verification" do
    it "includes pdf in supported formats" do
      formats = ParseKit::Parser.supported_formats
      expect(formats).to include("pdf")
    end

    it "recognizes .pdf files as supported" do
      expect(parser.supports_file?("document.pdf")).to be true
      expect(parser.supports_file?("DOCUMENT.PDF")).to be true
    end
  end

  describe "Performance and size limits" do
    let(:parser_with_limit) { ParseKit::Parser.new(max_size: 100) } # 100 bytes limit

    it "respects max_size configuration" do
      # Create a valid but large PDF that exceeds the size limit
      large_pdf = <<~PDF
        %PDF-1.4
        1 0 obj
        << /Type /Catalog /Pages 2 0 R >>
        endobj
        2 0 obj
        << /Type /Pages /Kids [3 0 R] /Count 1 >>
        endobj
        3 0 obj
        << /Type /Page /Parent 2 0 R /Resources << >> /MediaBox [0 0 612 792] >>
        endobj
        xref
        0 4
        0000000000 65535 f
        0000000009 00000 n
        0000000062 00000 n
        0000000121 00000 n
        trailer
        << /Size 4 /Root 1 0 R >>
        startxref
        250
        %%EOF
      PDF

      # Since parse_pdf is called directly, it bypasses the size check in parse_bytes_internal
      # We need to test through parse_bytes which includes the size check
      expect { parser_with_limit.parse_bytes(large_pdf.bytes) }.to raise_error(RuntimeError, /exceeds maximum/)
    end
  end

  describe "MuPDF static linking verification" do
    it "does not require external PDF libraries at runtime" do
      # This test verifies that the gem works without poppler/tesseract
      # by successfully parsing a PDF
      pdf_data = "%PDF-1.4\n1 0 obj\n<< /Type /Catalog >>\nendobj\nxref\n0 2\n0000000000 65535 f \n0000000009 00000 n \ntrailer\n<< /Size 2 /Root 1 0 R >>\nstartxref\n64\n%%EOF".bytes

      # This should work even without poppler installed
      expect { parser.parse_pdf(pdf_data) }.not_to raise_error
    end
  end
end
