# frozen_string_literal: true

require 'blueprinter'
require 'active_record'

module BlueprinterActiveRecord
  autoload :QueryMethods, 'blueprinter-activerecord/query_methods'
  autoload :Preloader, 'blueprinter-activerecord/preloader'
  autoload :AddedPreloadsLogger, 'blueprinter-activerecord/added_preloads_logger'
  autoload :MissingPreloadsLogger, 'blueprinter-activerecord/missing_preloads_logger'
  autoload :PreloadInfo, 'blueprinter-activerecord/preload_info'
  autoload :Helpers, 'blueprinter-activerecord/helpers'
  autoload :Version, 'blueprinter-activerecord/version'
end

ActiveRecord::Relation.send(:include, BlueprinterActiveRecord::QueryMethods)
ActiveRecord::Base.extend(BlueprinterActiveRecord::QueryMethods::Delegates)

require 'blueprinter-activerecord/railtie' if defined? Rails::Railtie
