# frozen_string_literal: true

module BlueprinterActiveRecord
  module Preloads
    autoload :ApiV1, 'blueprinter-activerecord/preloads/api_v1'

    def self.for(blueprint, view = nil)
      if defined?(Blueprinter::Base) && blueprint <= Blueprinter::Base
        ApiV1.preloads(blueprint, view || :default)
      else
        blueprint = blueprint[view] if view
        ApiV2.preloads(blueprint)
      end
    end
  end
end
