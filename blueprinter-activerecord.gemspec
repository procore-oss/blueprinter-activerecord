# frozen_string_literal: true

require_relative 'lib/blueprinter-activerecord/version'

Gem::Specification.new do |spec|
  spec.name = 'blueprinter-activerecord'
  spec.version = BlueprinterActiveRecord::VERSION
  spec.authors = ['Procore Technologies, Inc.']
  spec.email = ['opensource@procore.com']

  spec.summary = 'Extensions for using ActiveRecord with ActiveRecord'
  spec.description = 'Eager loading and other ActiveRecord helpers for Blueprinter'
  spec.homepage = 'https://github.com/procore-oss/blueprinter-activerecord'
  spec.license = 'MIT'
  spec.required_ruby_version = Gem::Requirement.new('>= 2.7')

  spec.metadata['homepage_uri'] = spec.homepage
  spec.metadata['source_code_uri'] = 'https://github.com/procore-oss/blueprinter-activerecord'
  spec.metadata['changelog_uri'] = 'https://github.com/procore-oss/blueprinter-activerecord/CHANGELOG.md'

  spec.files = Dir['lib/**/*']
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'activerecord', ['>= 6.0', '< 7.2']
  spec.add_runtime_dependency 'blueprinter', '~> 1.0'

  spec.add_development_dependency 'appraisal', '~> 2.5'
  spec.add_development_dependency 'database_cleaner', '~> 2.0'
  spec.add_development_dependency 'minitest', '~> 5.0'
  spec.add_development_dependency 'rake', '~> 13.0'
  spec.add_development_dependency 'sqlite3', '~> 1.4'
end
