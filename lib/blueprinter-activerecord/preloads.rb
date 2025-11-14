# frozen_string_literal: true

module BlueprinterActiveRecord
  module Preloads
    autoload :ApiV1, 'blueprinter-activerecord/preloads/api_v1'
    autoload :ApiV2, 'blueprinter-activerecord/preloads/api_v2'

    def self.for(blueprint, view = nil, model:)
      if defined?(Blueprinter::Base) && blueprint <= Blueprinter::Base
        ApiV1.preloads(blueprint, view || :default, model:)
      else
        blueprint = blueprint[view] if view
        ApiV2.preloads(blueprint, model:)
      end
    end
  end
end
