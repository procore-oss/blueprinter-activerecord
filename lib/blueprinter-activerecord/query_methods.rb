# frozen_string_literal: true

module BlueprinterActiveRecord
  module QueryMethods
    module Delegates
      def preload_blueprint(blueprint = nil, view = :default, use: :preload)
        all.preload_blueprint(blueprint, view, use: use)
      end
    end

    ACTIONS = %i(preload eager_load includes).freeze

    #
    # Automatically preload (or `eager_load` or `includes`) the associations in the given
    # blueprint and view (recursively).
    #
    # You can have the Blueprint and view autodetected on render:
    #
    #   q = Widget.where(...).preload_blueprint
    #   WidgetBlueprint.render(q, view: :extended)
    #
    # Or you can pass them up front:
    #
    #   widgets = Widget.where(...).preload_blueprint(WidgetBlueprint, :extended).to_a
    #   # do something with widgets, then render
    #   WidgetBlueprint.render(widgets, view: :extended)
    #
    # @param blueprint [Class] The Blueprinter class to use (ignore to autodetect on render)
    # @param view [Symbol] The Blueprinter view name to use (ignore to autodetect on render)
    # @param use [Symbol] The eager loading strategy to use (:preload, :includes, :eager_load)
    # @return [ActiveRecord::Relation]
    #
    def preload_blueprint(blueprint = nil, view = :default, use: :preload)
      spawn.preload_blueprint!(blueprint, view, use: use)
    end

    # See preload_blueprint
    def preload_blueprint!(blueprint = nil, view = :default, use: :preload)
      unless ACTIONS.include? use
        valid = ACTIONS.map(&:inspect).join(", ")
        raise BlueprinterError, "Unknown `preload_blueprint` method :#{use}. Valid methods are #{valid}."
      end

      if blueprint and view
        # preload right now
        preloads = Preloader.preloads(blueprint, view, model: model)
        public_send(use, preloads)
      else
        # preload during render
        @values[:preload_blueprint_method] = use
        self
      end
    end

    def preload_blueprint_method
      @values[:preload_blueprint_method]
    end

    # Get the preloads present before the Preloader extension ran (internal, for PreloadLogger)
    def before_preload_blueprint
      @values[:before_preload_blueprint]
    end

    # Set the preloads present before the Preloader extension ran (internal, for PreloadLogger)
    def before_preload_blueprint=(val)
      @values[:before_preload_blueprint] = val
    end
  end
end
