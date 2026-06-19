# frozen_string_literal: true

require_relative "lib/parsekit/version"

Gem::Specification.new do |spec|
  spec.name = "parsekit"
  spec.version = ParseKit::VERSION
  spec.authors = ["Chris Petersen"]
  spec.email = ["chris@petersen.io"]

  spec.summary = "Ruby document parsing toolkit with PDF and OCR support"
  spec.description = "Native Ruby gem for parsing documents (PDF, DOCX, XLSX, images with OCR) with zero runtime dependencies. Statically links MuPDF for PDF extraction and Tesseract for OCR."
  spec.homepage = "https://github.com/scientist-labs/parsekit"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.0.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.chdir(__dir__) do
    Dir["lib/**/*"] + Dir["ext/**/*.rs", "ext/**/*.toml", "ext/**/*.rb"] +
    ["README.md", "LICENSE.txt", "CHANGELOG.md"].select { |f| File.exist?(f) }
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Precompiled platform gems (arm64-darwin, x86_64-linux, ...) carry one compiled
  # extension per Ruby ABI under lib/parsekit/<major.minor>/ and must NOT declare
  # extensions, or RubyGems would try to recompile from Rust source on install —
  # defeating the precompiled gem. The shared rust-gem-release workflow sets
  # RUST_GEM_PLATFORM to enter this branch when assembling the fat darwin gem;
  # the linux platform gems are assembled by rake-compiler/rb_sys (via cross-gem),
  # which clears extensions itself. The per-ABI .bundle/.so are build artifacts
  # (gitignored) added explicitly here so they are packed by `gem build`.
  # Unset => normal source gem that compiles on install.
  if (platform_gem = ENV["RUST_GEM_PLATFORM"])
    spec.platform   = platform_gem
    spec.extensions = []
    spec.files     += Dir["lib/parsekit/*/parsekit.bundle"] + Dir["lib/parsekit/*/parsekit.so"]
  else
    spec.extensions = ["ext/parsekit/extconf.rb"]
  end

  # Runtime dependencies
  spec.add_dependency "rb_sys", "~> 0.9"

  # Development dependencies
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rake-compiler", "~> 1.2"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "simplecov", "~> 0.22"
end
