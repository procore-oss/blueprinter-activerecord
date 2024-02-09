# frozen_string_literal: true

require 'bundler/setup'
require 'bundler/gem_tasks'
require 'minitest/test_task'

# "test" command will accept files or dirs as args, plus N=pattern or X=pattern to include/exclude individual tests
Minitest::TestTask.create(:test) do |t|
  globs = ARGV[1..].map { |x|
    if Dir.exist? x
      "#{x}/**/*_test.rb"
    elsif File.exist? x
      x
    end
  }.compact

  t.libs << "test"
  t.libs << "lib"
  t.warning = false
  t.test_globs = globs.any? ? globs : ["test/**/*_test.rb"]
end
