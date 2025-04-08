# frozen_string_literal: true

module BlueprinterActiveRecord
  # A Blueprinter extension to automatically preload a Blueprint view's ActiveRecord associations during render
  class Preloader < Blueprinter::Extension
    include Helpers
    attr_reader :use, :auto, :auto_proc

    #
    # Initialize and configure the extension.
    #
    # V2 block arg: A Context struct containing the object, the blueprint, the options, and more.
    #
    # Legacy/V1 block args: The object to render, the blueprint class, the view name, and options.
    #
    # @param auto [true|false] When true, preload for EVERY ActiveRecord::Relation passed to a Blueprint
    # @param use [:preload|:includes] When `auto` is true, use this method (e.g. :preload) for preloading
    # @yield Instead of passing `auto` as a boolean, you may define a block that returns true when you want auto preloading to happen. See above for the block's args.
    #
    def initialize(auto: false, use: :preload, &auto_proc)
      @auto = auto
      @auto_proc = auto_proc
      @use =
        case use
        when :preload, :includes
          use
        else
          raise ArgumentError, "Unknown value '#{use.inspect}' for `BlueprinterActiveRecord::Preloader` argument 'use'. Valid values are :preload, :includes."
        end
    end

    # Tell Blueprinter (V2) to treat ActiveRecord::Relation objects like collections
    def collection?(ctx)
      ctx.object.is_a? ActiveRecord::Relation
    end

    # Perform preloading for ActiveRecord::Relation objects (Blueprinter V2).
    def input_collection(ctx)
      object = ctx.object
      return object unless object.is_a? ActiveRecord::Relation
      return object unless object.preload_blueprint_method || auto || auto_proc&.call(ctx) == true

      object.before_preload_blueprint = extract_preloads object
      blueprint_preloads = Preloads::ApiV2.preloads(ctx.blueprint, model: object.model)
      loader = object.preload_blueprint_method || use
      object.public_send(loader, blueprint_preloads)
    end

    #
    # Implements the "pre_render" Blueprinter Legacy/V1 Extension to preload associations from a view.
    # If auto is true, all ActiveRecord::Relation and ActiveRecord::AssociationRelation objects
    # will be preloaded. If auto is false, only queries that have called `.preload_blueprint`
    # will be preloaded.
    #
    # NOTE: If auto is on, *don't* be concerned that you'll end up with duplicate preloads. Even if
    # the query ends up with overlapping members in 'preload' and 'includes', ActiveRecord
    # intelligently handles them. There are several unit tests which confirm this behavior.
    #
    def pre_render(object, blueprint, view, options)
      if object.is_a?(ActiveRecord::Relation) && !object.loaded?
        if object.preload_blueprint_method || auto || auto_proc&.call(object, blueprint, view, options) == true
          object.before_preload_blueprint = extract_preloads object
          blueprint_preloads = Preloads::ApiV1.preloads(blueprint, view, model: object.model)
          loader = object.preload_blueprint_method || use
          object.public_send(loader, blueprint_preloads)
        else
          object
        end
      else
        object
      end
    end
  end
end
