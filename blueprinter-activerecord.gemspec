# frozen_string_literal: true

require_relative 'lib/blueprinter-activerecord/version'

Gem::Specification.new do |spec|
  spec.name = 'blueprinter-activerecord'
  spec.version = BlueprinterActiveRecord::VERSION
  spec.authors = ['Procore Technologies, Inc.']
  spec.email = ['opensource@procore.com']

  spec.summary = 'Extensions for using Blueprinter with ActiveRecord'
  spec.description = 'Eager loading and other ActiveRecord helpers for Blueprinter'
  spec.homepage = 'https://github.com/procore-oss/blueprinter-activerecord'
  spec.license = 'MIT'
  spec.required_ruby_version = Gem::Requirement.new('>= 3.1')

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/procore-oss/blueprinter-activerecord'
  spec.metadata['changelog_uri'] = 'https://github.com/procore-oss/blueprinter-activerecord/CHANGELOG.md'
  spec.metadata['allowed_push_host'] = 'https://rubygems.org'
  spec.metadata['rubygems_mfa_required'] = 'true'

  spec.files = Dir['lib/**/*']
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'activerecord', ['>= 7.1']
  spec.add_runtime_dependency 'blueprinter', '~> 1.0'
end
