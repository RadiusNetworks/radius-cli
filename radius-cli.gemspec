# frozen_string_literal: true

lib = File.expand_path("lib", __dir__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "radius/cli/version"

Gem::Specification.new do |spec|
  spec.name          = "radius-cli"
  spec.version       = Radius::Cli::VERSION
  spec.authors       = ["Radius Networks"]
  spec.email         = ["support@radiusnetworks.com"]

  spec.summary       = "Radius developer command line tools"
  spec.description   = "Radius developer command line tools."
  spec.homepage      = "https://github.com/RadiusNetworks/radius-cli"
  spec.license       = "Apache-2.0"

  # Prevent pushing this gem to RubyGems.org. To allow pushes either set the 'allowed_push_host'
  # to allow pushing to a single host or delete this section to allow pushing to any host.
  spec.metadata      = {
    "homepage_uri"    => spec.homepage,
    "bug_tracker_uri" => "https://github.com/RadiusNetworks/radius-cli/issues",
    "changelog_uri"   => "https://github.com/RadiusNetworks/radius-cli/blob/v#{Radius::Cli::VERSION}/CHANGELOG.md",
    "source_code_uri" => "https://github.com/RadiusNetworks/radius-cli/tree/v#{Radius::Cli::VERSION}",
  }

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end

  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.required_ruby_version = ">= 2.5"

  spec.add_runtime_dependency "dotenv", "~> 2.5"
  spec.add_runtime_dependency "thor", "~> 1.0"

  spec.add_development_dependency "bundler", "~> 1.17"
  spec.add_development_dependency "radius-spec", "~> 0.5"
  spec.add_development_dependency "rake", "~> 10.0"
end
