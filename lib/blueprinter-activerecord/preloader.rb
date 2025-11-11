# frozen_string_literal: true

module BlueprinterActiveRecord
  # A Blueprinter extension to automatically preload a Blueprint view's ActiveRecord associations during render
  class Preloader < Blueprinter::Extension
    include Helpers
    DEFAULT_MAX_RECURSION = 10

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
    # If auto is true, all ActiveRecord::Relation and ActiveRecord::AssociationRelation objects
    # will be preloaded. If auto is false, only queries that have called `.preload_blueprint`
    # will be preloaded.
    #
    # The caller may skip auto preloading by passing { preload: false } as an option.
    #
    # NOTE: If auto is on, *don't* be concerned that you'll end up with duplicate preloads. Even if
    # the query ends up with overlapping members in 'preload' and 'includes', ActiveRecord
    # intelligently handles them. There are several unit tests which confirm this behavior.
    #
    def pre_render(object, blueprint, view, options)
      if object.is_a?(ActiveRecord::Relation) && !object.loaded? && options[:preload] != false
        if object.preload_blueprint_method || auto || auto_proc&.call(object, blueprint, view, options) == true
          object.before_preload_blueprint = extract_preloads object
          blueprint_preloads = self.class.preloads(blueprint, view, model: object.model)
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
    # Preloads are found when one of the model's associations matches:
    # 1. A Blueprint association name.
    # 2. A :preload option on a field or association.
    #
    # Example:
    #
    #   preloads = BlueprinterActiveRecord::Preloader.preloads(WidgetBlueprint, :extended, model: Widget)
    #   q = Widget.where(...).order(...).preload(preloads)
    #
    # @param blueprint [Class] The Blueprint class
    # @param view_name [Symbol] Name of the view in blueprint
    # @param model [Class|:polymorphic] The ActiveRecord model class that blueprint represents
    # @param cycles [Hash<String, Integer>] (internal) Preloading will halt if recursion/cycles gets too high
    # @return [Hash] A Hash containing preload/eager_load/etc info for ActiveRecord
    #
    def self.preloads(blueprint, view_name, model:, cycles: {})
      view = blueprint.reflections.fetch(view_name)
      preload_vals = view.associations.each_with_object({}) { |(_name, assoc), acc|
        # look for a matching association on the model
        if (preload = association_preloads(assoc, model, cycles))
          acc[assoc.name] = preload
        end

        # look for a :preload option on the association
        if (custom = assoc.options[:preload])
          Helpers.merge_values custom, acc
        end
      }

      # look for a :preload options on fields
      view.fields.each_with_object(preload_vals) { |(_name, field), acc|
        if (custom = field.options[:preload])
          Helpers.merge_values custom, acc
        end
      }
    end

    def self.association_preloads(assoc, model, cycles)
      max_cycles = assoc.options.fetch(:max_recursion, DEFAULT_MAX_RECURSION)
      if model == :polymorphic
        if assoc.blueprint.is_a? Proc
          {}
        else
          cycles, count = count_cycles(assoc.blueprint, assoc.view, cycles)
          count < max_cycles ? preloads(assoc.blueprint, assoc.view, model: model, cycles: cycles) : {}
        end
      elsif (ref = model.reflections[assoc.name.to_s])
        if assoc.blueprint.is_a? Proc
          {}
        elsif ref.belongs_to? && ref.polymorphic?
          cycles, count = count_cycles(assoc.blueprint, assoc.view, cycles)
          count < max_cycles ? preloads(assoc.blueprint, assoc.view, model: :polymorphic, cycles: cycles) : {}
        else
          cycles, count = count_cycles(assoc.blueprint, assoc.view, cycles)
          count < max_cycles ? preloads(assoc.blueprint, assoc.view, model: ref.klass, cycles: cycles) : {}
        end
      end
    end

    def self.count_cycles(blueprint, view, cycles)
      id = "#{blueprint.name || blueprint.inspect}/#{view}"
      cycles = cycles.dup
      if cycles[id].nil?
        cycles[id] = 0
      else
        cycles[id] += 1
      end
      return cycles, cycles[id]
    end
  end
end
