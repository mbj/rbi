# typed: true
# frozen_string_literal: true

require_relative "lib/rbi/version"

Gem::Specification.new do |spec|
  spec.name          = "rbi"
  spec.version       = RBI::VERSION
  spec.authors       = ["Alexandre Terrasa"]
  spec.email         = ["alexandre.terrasa@shopify.com"]

  spec.summary       = "RBI generation framework"
  spec.homepage      = "https://github.com/Shopify/rbi"
  spec.license       = "MIT"
  spec.required_ruby_version = Gem::Requirement.new(">= 2.4.0")

  spec.metadata["allowed_push_host"] = "https://rubygems.org"

  spec.require_paths = ["lib"]

  spec.files         = Dir.glob("lib/**/*.rb") + %w(
    README.md
    Gemfile
    Rakefile
  )

  spec.add_dependency("ast")
  spec.add_dependency("parser")
  spec.add_dependency("rake", "~> 13.0")
  spec.add_dependency("sorbet-runtime")
  spec.add_dependency("thor")
  spec.add_dependency("unparser")
end
