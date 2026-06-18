# frozen_string_literal: true

require "bundler/gem_tasks"
require "rake/extensiontask"

# Dev-only tasks (rspec) must not abort Rakefile loading in the cross-gem /
# rb-sys-dock build container, which installs only the runtime bundle. Guard the
# require + task definition so `rake native:<platform>` works without dev gems.
begin
  require "rspec/core/rake_task"
  RSpec::Core::RakeTask.new(:spec)
rescue LoadError
  desc "Run RSpec tests (rspec not installed)"
  task :spec do
    abort "rspec is not available. Install the development dependencies (bundle install)."
  end
end

# Load the gemspec so Rake::ExtensionTask emits native:<platform> tasks (the
# cross-gem / rb-sys-dock entrypoint) in addition to compile.
spec = Gem::Specification.load("parsekit.gemspec")

# Extension compilation task
Rake::ExtensionTask.new("parsekit", spec) do |ext|
  ext.lib_dir = "lib/parsekit"
  ext.source_pattern = "*.{c,cc,cpp,rs}"
  ext.cross_compile = true
  ext.cross_platform = %w[x86_64-linux aarch64-linux arm64-darwin x86_64-darwin]
end

# Work around rake-compiler trying to stage non-existent build artifacts
# This happens when dependencies generate files during their build process
# Create dummy files for the ones that cause errors to satisfy rake-compiler
task :before_compile do
  # Common build artifacts that rake-compiler tries to copy but don't exist after clean
  problem_files = [
    "ext/parsekit/target/release/build/clang-sys-*/out/common.rs",
    "ext/parsekit/target/release/build/mupdf-sys-*/out/bindings.rs",
    "ext/parsekit/target/release/build/rb-sys-*/out/*.rs",
    "ext/parsekit/target/release/build/typenum-*/out/*.rs",
    "ext/parsekit/target/release/build/rav1e-*/out/*.rs"
  ]
  
  problem_files.each do |pattern|
    Dir.glob(pattern).each do |file|
      # These files will be regenerated during the actual build
      # We just need them to exist to prevent rake errors
      unless File.exist?(file)
        FileUtils.mkdir_p(File.dirname(file))
        FileUtils.touch(file)
      end
    end
  end
end

# Ensure our workaround runs before compilation
task compile: :before_compile

# Default task runs compile then tests
task default: [:compile, :spec]

# Clean task
desc "Remove compiled artifacts"
task :clean do
  FileUtils.rm_rf("lib/parsekit/*.bundle")
  FileUtils.rm_rf("lib/parsekit/*.so")
  FileUtils.rm_rf("lib/parsekit/*.dll")
  FileUtils.rm_rf("tmp")
  FileUtils.rm_rf("pkg")
  Dir.chdir("ext/parsekit") do
    sh "cargo clean" if File.exist?("Cargo.toml")
  end
end

# Clobber task (more aggressive clean)
desc "Remove all generated files"
task clobber: :clean do
  FileUtils.rm_rf("Gemfile.lock")
  FileUtils.rm_rf(".rspec_status")
  FileUtils.rm_rf("coverage")
end

# Rust-specific tasks
namespace :rust do
  desc "Run cargo fmt"
  task :fmt do
    Dir.chdir("ext/parsekit") do
      sh "cargo fmt"
    end
  end
  
  desc "Run cargo fmt check"
  task :fmt_check do
    Dir.chdir("ext/parsekit") do
      sh "cargo fmt -- --check"
    end
  end
  
  desc "Run cargo test"
  task :test do
    Dir.chdir("ext/parsekit") do
      sh "cargo test"
    end
  end
  
  desc "Run cargo clippy"
  task :clippy do
    Dir.chdir("ext/parsekit") do
      sh "cargo clippy -- -D warnings"
    end
  end
  
  desc "Run cargo check"
  task :check do
    Dir.chdir("ext/parsekit") do
      sh "cargo check"
    end
  end
  
  desc "Update Rust dependencies"
  task :update do
    Dir.chdir("ext/parsekit") do
      sh "cargo update"
    end
  end
end

# Development tasks
namespace :dev do
  desc "Run tests with coverage"
  task :coverage do
    ENV["COVERAGE"] = "true"
    Rake::Task["spec"].invoke
  end
  
  desc "Open coverage report in browser"
  task :coverage_open do
    system "open coverage/index.html"
  end
  
  desc "Open console with gem loaded"
  task :console do
    require "irb"
    require "irb/completion"
    require "parsekit"
    ARGV.clear
    IRB.start
  end
  
  desc "Run benchmarks"
  task benchmark: :compile do
    ruby "benchmark/benchmark.rb"
  end
end

# Documentation tasks
begin
  require "yard"
  YARD::Rake::YardocTask.new do |t|
    t.files = ["lib/**/*.rb", "ext/**/*.rs"]
    t.options = ["--no-private", "--markup", "markdown"]
  end
rescue LoadError
  desc "Generate documentation (requires YARD)"
  task :yard do
    puts "YARD is not available. Install it with: gem install yard"
  end
end

# CI-specific tasks
namespace :ci do
  desc "Run all CI checks"
  task all: [:compile, :spec, "rust:fmt_check", "rust:clippy", "rust:test"]
  
  desc "Setup CI environment"
  task :setup do
    sh "bundle install"
    sh "rustup component add rustfmt clippy"
  end
end

# Platform-specific compilation helpers
namespace :compile do
  desc "Compile for current platform with debug symbols"
  task :debug do
    ENV["DEBUG"] = "true"
    Rake::Task["compile"].invoke
  end
  
  desc "Compile for release (optimized)"
  task :release do
    ENV["RELEASE"] = "true"
    Rake::Task["compile"].invoke
  end
end

# Release tasks
namespace :release do
  desc "Build native gems for all platforms"
  task :native do
    # This would be run on CI with proper cross-compilation setup
    platforms = %w[x86_64-linux arm64-darwin x86_64-darwin aarch64-linux]
    platforms.each do |platform|
      puts "Building for #{platform}..."
      ENV["RUBY_CC_VERSION"] = "3.0.0:3.1.0:3.2.0:3.3.0"
      sh "rake native:#{platform} gem"
    end
  end
end