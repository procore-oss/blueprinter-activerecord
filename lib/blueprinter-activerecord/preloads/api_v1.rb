# frozen_string_literal: true

module BlueprinterActiveRecord
  module Preloads
    module ApiV1
      DEFAULT_MAX_RECURSION = 10

      #
      # Returns an ActiveRecord preload plan extracted from the Blueprint and view (recursive).
      #
      # Preloads are found when one of the model's associations matches:
      # 1. A Blueprint association name.
      # 2. A :preload option on a field or association.
      #
      # Example:
      #
      #   preloads = BlueprinterActiveRecord::Preloads::ApiV1.preloads(WidgetBlueprint, :extended, model: Widget)
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
          preload = association_preloads(model, assoc.name, blueprint: assoc.blueprint, view: assoc.view, options: assoc.options, cycles:)
          acc[assoc.name] = preload if preload

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

      def self.association_preloads(model, name, blueprint:, view:, options:, cycles:)
        return {} if blueprint.is_a? Proc

        if defined?(::Blueprinter::V2) && blueprint <= ::Blueprinter::V2::Base
          blueprint = blueprint[options[:view]] if options[:view]
          return ApiV2.association_preloads(model, name.to_s, blueprint:, options:, cycles:)
        end

        max_cycles = options.fetch(:max_recursion, DEFAULT_MAX_RECURSION)
        if model == :polymorphic
          cycles, count = count_cycles(blueprint, view, cycles)
          count < max_cycles ? preloads(blueprint, view, model:, cycles:) : {}
        elsif (ref = model.reflections[name.to_s])
          if ref.belongs_to? && ref.polymorphic?
            cycles, count = count_cycles(blueprint, view, cycles)
            count < max_cycles ? preloads(blueprint, view, model: :polymorphic, cycles:) : {}
          else
            cycles, count = count_cycles(blueprint, view, cycles)
            count < max_cycles ? preloads(blueprint, view, model: ref.klass, cycles:) : {}
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
end
