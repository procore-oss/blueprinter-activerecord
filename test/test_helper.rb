# frozen_string_literal: true

require 'blueprinter'
require 'active_record'
require 'blueprinter-activerecord'
require 'minitest/autorun'

Dir.glob("./test/support/*.rb").each { |file| require file }

Schema.load!
