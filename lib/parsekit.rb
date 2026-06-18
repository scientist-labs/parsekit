# frozen_string_literal: true

require_relative "parsekit/version"

# Load the compiled Rust extension. Precompiled (platform) gems install it into a
# Ruby-ABI-versioned subdir (lib/parsekit/<major.minor>/parsekit.{so,bundle}) so a
# single fat gem can carry a binary per Ruby version; source/dev builds place it flat
# at lib/parsekit/parsekit.{so,bundle}. Try the versioned path first, fall back to the
# flat one. Resolution goes through $LOAD_PATH (`require`, never `require_relative`)
# because RubyGems installs native extensions outside the gem's lib/ dir.
begin
  RUBY_VERSION =~ /(\d+\.\d+)/
  require "parsekit/#{Regexp.last_match(1)}/parsekit"
rescue LoadError
  require "parsekit/parsekit"
end

require_relative "parsekit/error"
require_relative "parsekit/parser"

# ParseKit is a Ruby document parsing toolkit with PDF and OCR support
module ParseKit
  # Supported file formats and their extensions
  SUPPORTED_FORMATS = {
    pdf: ['.pdf'],
    docx: ['.docx'],
    xlsx: ['.xlsx'],
    xls: ['.xls'],
    pptx: ['.pptx'],
    png: ['.png'],
    jpeg: ['.jpg', '.jpeg'],
    tiff: ['.tiff', '.tif'],
    bmp: ['.bmp'],
    json: ['.json'],
    xml: ['.xml', '.html'],
    text: ['.txt', '.md', '.csv']
  }.freeze

  class << self
    # The parse_file and parse_bytes methods are defined in the native extension
    # We just need to document them here or add wrapper logic if needed
    
    # Convenience method to parse input directly (for text)
    # @param input [String] The input string to parse
    # @param options [Hash] Optional configuration options
    # @option options [String] :encoding Input encoding (default: UTF-8)
    # @return [String] The parsed result
    def parse(input, options = {})
      Parser.new(options).parse(input)
    end
    
    # Parse binary data
    # @param data [String, Array] Binary data to parse
    # @param options [Hash] Optional configuration options
    # @return [String] The extracted text
    def parse_bytes(data, options = {})
      # Convert string to bytes if needed
      byte_data = data.is_a?(String) ? data.bytes : data
      Parser.new(options).parse_bytes(byte_data)
    end
    
    # Get supported file formats
    # @return [Array<String>] List of supported file extensions
    def supported_formats
      Parser.supported_formats
    end
    
    # Check if a file format is supported
    # @param path [String] File path to check
    # @return [Boolean] True if the file format is supported
    def supports_file?(path)
      Parser.new.supports_file?(path)
    end
    
    # Detect file format from filename/extension
    # @param filename [String, nil] The filename to check
    # @return [Symbol] The detected format, or :unknown
    def detect_format(filename)
      return :unknown if filename.nil? || filename.empty?
      
      ext = File.extname(filename).downcase
      return :unknown if ext.empty?
      
      SUPPORTED_FORMATS.each do |format, extensions|
        return format if extensions.include?(ext)
      end
      
      :unknown
    end
    
    # Get the native library version
    # @return [String] Version of the native library
    def native_version
      version
    rescue StandardError
      "unknown"
    end
  end
end