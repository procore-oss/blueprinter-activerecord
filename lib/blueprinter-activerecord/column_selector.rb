# frozen_string_literal: true

module BlueprinterActiveRecord
  # A Blueprinter extension to automatically select only the columns needed by a Blueprint view
  class ColumnSelector < Blueprinter::Extension
    attr_reader :auto, :auto_proc

    #
    # Initialize and configure the extension.
    #
    # @param auto [true|false] When true, select columns for EVERY ActiveRecord::Relation passed to a Blueprint
    # @yield [Object, Class, Symbol, Hash] Instead of passing `auto` as a boolean, you may define a block that accepts the object to render, the blueprint class, the view, and options. If the block returns true, auto column selection will take place.
    #
    def initialize(auto: false, &auto_proc)
      @auto = auto
      @auto_proc = auto_proc
    end

    #
    # Implements the "pre_render" Blueprinter Extension to select only needed columns from a view.
    # If auto is true, all ActiveRecord::Relation objects
    # will have their columns optimized. If auto is false, only queries that have called `.select_blueprint_columns`
    # will be optimized.
    #
    def pre_render(object, blueprint, view, options)
      if object.is_a?(ActiveRecord::Relation) && !object.loaded?
        if object.select_blueprint_columns_method || auto || auto_proc&.call(object, blueprint, view, options) == true
          # Store original select values for logging
          object.before_select_blueprint_columns = extract_selects(object)
          
          # Get the columns needed by this blueprint view
          blueprint_columns = self.class.columns(blueprint, view, model: object.model)
          
          # Apply the column selection
          object.select(*blueprint_columns) if blueprint_columns.any?
        else
          object
        end
      else
        object
      end
    end

    private

    #
    # Returns an array of column names needed by the Blueprint and view.
    #
    # Columns are found from:
    # 1. Blueprint field names that match model column names
    # 2. Foreign key columns for associations (always included when associations are present)
    # 3. Explicit :select options on fields
    #
    # Example:
    #
    #   columns = BlueprinterActiveRecord::ColumnSelector.columns(WidgetBlueprint, :extended, model: Widget)
    #   q = Widget.where(...).select(*columns)
    #
    # @param blueprint [Class] The Blueprint class
    # @param view_name [Symbol] Name of the view in blueprint
    # @param model [Class|:polymorphic] The ActiveRecord model class that blueprint represents
    # @return [Array<String>] Array of column names to select
    #
    def self.columns(blueprint, view_name, model:)
      view = blueprint.reflections.fetch(view_name)
      columns = Set.new

      # Process fields
      view.fields.each do |field_name, field|
        columns.add(field.name.to_s) if model.column_names.include?(field.name.to_s)

        # Check if field has explicit select option
        if (custom_select = field.options[:select])
          case custom_select
          when String, Symbol
            raise ArgumentError, "Blueprint field #{field_name} has explicit select option #{custom_select} that does not match a column on the model #{model.name}" unless model.column_names.include?(custom_select.to_s)
            columns.add(custom_select.to_s)
          when Array
            columns.merge(custom_select.map(&:to_s))
          end
        end
      end
      
      # Process associations to get foreign keys
      view.associations.each do |assoc_name, assoc|
        if model.respond_to?(:reflections) && (ref = model.reflections[assoc_name.to_s])
          # Add foreign key columns for belongs_to associations
          if ref.belongs_to?
            columns.add(ref.foreign_key) if ref.foreign_key
            columns.add(ref.foreign_type) if ref.foreign_type # in case it was polymorphic
          elsif ref.through_reflection
            # For has_many/one through belongs_to associations, we need the foreign key of the intermediate association
            # Example: has_many :customer_projects, through: :customer
            # We need the customer_id foreign key
            through_ref = ref.through_reflection
            if through_ref.belongs_to?
              columns.add(through_ref.foreign_key) if through_ref.foreign_key
              columns.add(through_ref.foreign_type) if through_ref.foreign_type # in case it was polymorphic
            end
          end
        end
      end
      # Databases often cache query plans. Consistent column order means:
      # - Same SQL string → same cached plan
      # - Better database performance
      # - Less chance of unexpected changes in query results
      columns.to_a.flatten.sort
    end

    #
    # Extract existing select values from a query
    #
    def extract_selects(query)
      query.values[:select] || []
    end
  end
end 