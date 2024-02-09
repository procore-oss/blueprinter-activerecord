# frozen_string_literal: true

module BlueprinterActiveRecord
  # A Blueprinter extension to automatically preload a Blueprint view's ActiveRecord associations during render
  class Preloader < Blueprinter::Extension
    include Helpers

    attr_reader :use, :auto, :auto_proc

    #
    # Initialize and configure the extension.
    #
    # @param auto [true|false] When true, preload for EVERY ActiveRecord::Relation passed to a Blueprint
    # @param use [:preload|:includes] When `auto` is true, use this method (e.g. :preload) for preloading
    # @yield [Object, Class, Symbol, Hash] Instead of passing `auto` as a boolean, you may define a block that accepts the object to render, the blueprint class, the view, and options. If the block returns true, auto preloading will take place.
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

    #
    # Implements the "pre_render" Blueprinter Extension to preload associations from a view.
    # If auto is true, all ActiveRecord::Relation objects will be preloaded. If auto is false,
    # only queries that have called `.preload_blueprint` will be preloaded.
    #
    # NOTE: If auto is on, *don't* be concerned that you'll end up with duplicate preloads. Even if
    # the query ends up with overlapping members in 'preload' and 'includes', ActiveRecord
    # intelligently handles them. There are several unit tests which confirm this behavior.
    #
    def pre_render(object, blueprint, view, options)
      case object
      when ActiveRecord::Relation
        if object.preload_blueprint_method || auto || auto_proc&.call(object, blueprint, view, options) == true
          object.before_preload_blueprint = extract_preloads object
          blueprint_preloads = self.class.preloads(blueprint, view, object.model)
          loader = object.preload_blueprint_method || use
          object.public_send(loader, blueprint_preloads)
        else
          object
        end
      else
        object
      end
    end

    private

    #
    # Returns an ActiveRecord preload plan extracted from the Blueprint and view (recursive).
    #
    # Example:
    #
    #   preloads = BlueprinterActiveRecord::Preloader.preloads(WidgetBlueprint, :extended, Widget)
    #   q = Widget.where(...).order(...).preload(preloads)
    #
    # @param blueprint [Class] The Blueprint class
    # @param view_name [Symbol] Name of the view in blueprint
    # @param model [Class] The ActiveRecord model class that blueprint represents
    # @return [Hash] A Hash containing preload/eager_load/etc info for ActiveRecord
    #
    def self.preloads(blueprint, view_name, model=nil)
      view = blueprint.reflections.fetch(view_name)
      view.associations.each_with_object({}) { |(_name, assoc), acc|
        ref = model ? model.reflections[assoc.name.to_s] : nil
        if (ref || model.nil?) && !assoc.blueprint.is_a?(Proc)
          ref_model = ref && !(ref.belongs_to? && ref.polymorphic?) ? ref.klass : nil
          acc[assoc.name] = preloads(assoc.blueprint, assoc.view, ref_model)
        end
      }
    end
  end
end
