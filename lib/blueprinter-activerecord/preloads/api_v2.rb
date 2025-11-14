# frozen_string_literal: true

module BlueprinterActiveRecord
  module Preloads
    module ApiV2
      DEFAULT_MAX_RECURSION = 10

      def self.preloads(blueprint, model:, cycles: {})
        ref = blueprint.reflections[:default]
        potential_associations = ref.objects.values + ref.collections.values
        preload_vals = potential_associations.each_with_object({}) do |assoc, acc|
          # look for a matching association on the model
          preload = association_preloads(model, assoc.from_str, blueprint: assoc.blueprint, options: assoc.options, cycles:)
          acc[assoc.from] = preload if preload

          # look for a :preload option on the object/collection
          if (custom = assoc.options[:preload])
            Helpers.merge_values custom, acc
          end
        end

        # look for a :preload options on regular fields
        ref.fields.each_with_object(preload_vals) { |(_name, field), acc|
          if (custom = field.options[:preload])
            Helpers.merge_values custom, acc
          end
        }
      end

      def self.association_preloads(model, name, blueprint:, options:, cycles:)
        return {} if blueprint.is_a? Proc

        if defined?(::Blueprinter::ViewWrapper) && blueprint.is_a?(::Blueprinter::ViewWrapper)
          return ApiV1.association_preloads(model, name, blueprint: blueprint.blueprint, view: blueprint.view_name, options:, cycles:)
        end

        if defined?(::Blueprinter::Base) && blueprint <= ::Blueprinter::Base
          return ApiV1.association_preloads(model, name, blueprint:, view: :default, options:, cycles:)
        end

        max_cycles = options.fetch(:max_recursion, DEFAULT_MAX_RECURSION)
        if model == :polymorphic
          cycles, count = count_cycles(blueprint, cycles)
          count < max_cycles ? preloads(blueprint, model:, cycles:) : {}
        elsif (ref = model.reflections[name])
          if ref.belongs_to? && ref.polymorphic?
            cycles, count = count_cycles(blueprint, cycles)
            count < max_cycles ? preloads(blueprint, model: :polymorphic, cycles:) : {}
          else
            cycles, count = count_cycles(blueprint, cycles)
            count < max_cycles ? preloads(blueprint, model: ref.klass, cycles:) : {}
          end
        end
      end

      def self.count_cycles(blueprint, cycles)
        id = blueprint.to_s
        cycles = cycles.dup
        if cycles[id].nil?
          cycles[id] = 0
        else
          cycles[id] += 1
        end
        return cycles, cycles[id]
      end

      # Preload into an existing record
      def self.preload_into(record, preloads)
        case ActiveRecord::VERSION::MAJOR
        when 7, 8
          ActiveRecord::Associations::Preloader.new(records: [record], associations: preloads).call
        else
          raise "Unsupported ActiveRecord version"
        end
      end
    end
  end
end
