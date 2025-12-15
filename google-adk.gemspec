# frozen_string_literal: true

require_relative "lib/google/adk/version"

Gem::Specification.new do |spec|
  spec.name = "google-adk"
  spec.version = Google::ADK::VERSION
  spec.authors = ["Landon Gray"]
  spec.email = ["thedayisntgray@gmail.com"]

  spec.summary = "Unofficial Ruby implementation of Google's Agent Development Kit"
  spec.description = "UNOFFICIAL Ruby port of Google's Agent Development Kit (ADK). This gem is not affiliated with, endorsed by, or maintained by Google. Build, evaluate, and deploy AI agents using the ADK framework in Ruby."
  spec.homepage = "https://github.com/thedayisntgray/google-adk"
  spec.license = "MIT"
  spec.required_ruby_version = ">= 3.1.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = "https://github.com/thedayisntgray/google-adk"
  spec.metadata["changelog_uri"] = "https://github.com/thedayisntgray/google-adk/blob/main/CHANGELOG.md"
  spec.metadata["documentation_uri"] = "https://rubydoc.info/gems/google-adk"
  spec.metadata["rubygems_mfa_required"] = "true"

  # Specify which files should be added to the gem when it is released.
  spec.files = Dir.glob(%w[
                          lib/**/*.rb
                          google-adk.gemspec
                          README.md
                          CHANGELOG.md
                          LICENSE.txt
                        ])
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{\Aexe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  # Runtime dependencies
  spec.add_dependency "async", "~> 2.0"
  spec.add_dependency "concurrent-ruby", "~> 1.2"
  spec.add_dependency "dotenv", "~> 2.8"
  spec.add_dependency "faraday", "~> 2.0"
  spec.add_dependency "google-cloud-ai_platform-v1", "~> 0.1"

  # Development dependencies
  spec.add_development_dependency "rake", "~> 13.0"
  spec.add_development_dependency "rspec", "~> 3.12"
  spec.add_development_dependency "rubocop", "~> 1.50"
  spec.add_development_dependency "rubocop-rspec", "~> 2.20"
  spec.add_development_dependency "simplecov", "~> 0.22"
  spec.add_development_dependency "vcr", "~> 6.1"
  spec.add_development_dependency "webmock", "~> 3.18"
  spec.add_development_dependency "yard", "~> 0.9"
end
