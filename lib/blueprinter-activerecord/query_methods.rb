# frozen_string_literal: true

module BlueprinterActiveRecord
  module QueryMethods
    module Delegates
      def preload_blueprint(blueprint = nil, view = :default, use: :preload)
        all.preload_blueprint(blueprint, view, use: use)
      end

      def select_blueprint_columns(blueprint = nil, view = :default)
        all.select_blueprint_columns(blueprint, view)
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

    #
    # Automatically select only the columns needed by the given blueprint and view.
    #
    # You can have the Blueprint and view autodetected on render:
    #
    #   q = Widget.where(...).select_blueprint_columns
    #   WidgetBlueprint.render(q, view: :extended)
    #
    # Or you can pass them up front:
    #
    #   widgets = Widget.where(...).select_blueprint_columns(WidgetBlueprint, :extended).to_a
    #   # do something with widgets, then render
    #   WidgetBlueprint.render(widgets, view: :extended)
    #
    # @param blueprint [Class] The Blueprinter class to use (ignore to autodetect on render)
    # @param view [Symbol] The Blueprinter view name to use (ignore to autodetect on render)
    # @return [ActiveRecord::Relation]
    #
    def select_blueprint_columns(blueprint = nil, view = :default)
      spawn.select_blueprint_columns!(blueprint, view)
    end

    # See select_blueprint_columns
    def select_blueprint_columns!(blueprint = nil, view = :default)
      if blueprint and view
        # select right now
        columns = ColumnSelector.columns(blueprint, view, model: model)
        select(*columns) if columns.any?
      else
        # select during render
        @values[:select_blueprint_columns_method] = true
        self
      end
    end

    def preload_blueprint_method
      @values[:preload_blueprint_method]
    end

    def select_blueprint_columns_method
      @values[:select_blueprint_columns_method]
    end

    # Get the preloads present before the Preloader extension ran (internal, for PreloadLogger)
    def before_preload_blueprint
      @values[:before_preload_blueprint]
    end

    # Set the preloads present before the Preloader extension ran (internal, for PreloadLogger)
    def before_preload_blueprint=(val)
      @values[:before_preload_blueprint] = val
    end

    # Get the selects present before the ColumnSelector extension ran (internal, for logging)
    def before_select_blueprint_columns
      @values[:before_select_blueprint_columns]
    end

    # Set the selects present before the ColumnSelector extension ran (internal, for logging)
    def before_select_blueprint_columns=(val)
      @values[:before_select_blueprint_columns] = val
    end
  end
end
