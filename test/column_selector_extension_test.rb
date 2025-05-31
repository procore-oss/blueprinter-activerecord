# frozen_string_literal: true

require 'test_helper'

class ColumnSelectorExtensionTest < Minitest::Test
  def setup
    DatabaseCleaner.start
    customer = Customer.create!(name: "ACME")
    project = Project.create!(customer:, name: "Project A")
    company = Company.create!(name: "Bar")
    category = Category.create!(name: "Foo", company: company)
    ref_plan = RefurbPlan.create!(name: "Plan A")
    battery1 = LiIonBattery.create!(num_ions: 100, num_other: 100, refurb_plan_id: ref_plan.id)
    battery2 = LeadAcidBattery.create!(num_lead: 100, num_acid: 100)
    vendor = Vendor.create!(name: "ACME Supplies", contact_email: "orders@acme.com")
    location = Location.create!(building_code: "A", room_number: "101", name: "Conference Room A")
    Widget.create!(customer:, project:, category:, name: "Widget A", description: 'test widget', price: 10.50, vendor: vendor, location:, battery1:, battery2:)
    Widget.create!(customer:, project:, category:, name: "Widget B", description: 'test widget', price: 20.75, vendor: vendor, location:, battery1:)
    Widget.create!(customer:, project:, category:, name: "Widget C", price: 30.25, battery1:)
    Blueprinter.configure do |config|
      config.extensions << BlueprinterActiveRecord::ColumnSelector.new(auto: true)
    end

    @query = Widget.where("name <> ?", "Widget C").order(:name)
    @auto_column_selector = BlueprinterActiveRecord::ColumnSelector.new(auto: true)
  end

  def teardown
    DatabaseCleaner.clean
    Blueprinter.configure do |config|
      config.extensions = []
    end
  end
  
  def test_auto_column_selection_for_default_view
    optimized_q = @auto_column_selector.pre_render(@query, WidgetBlueprint, :default, {})
    
    selected_columns = optimized_q.values[:select].map(&:to_s).sort
    expected_columns = ['id', 'name', 'price'].sort
    assert_equal expected_columns, selected_columns, "Should only select columns needed for default view"
    
    total_columns = Widget.column_names.size
    assert selected_columns.size < total_columns, "Should select fewer columns than total available: #{selected_columns.size} < #{total_columns}"

    widgets = WidgetBlueprint.render_as_hash(@query, view: :default)

    # Should render successfully with optimized columns
    assert_equal ["Widget A", "Widget B"], widgets.map { |w| w[:name] }
    assert_equal 2, widgets.map { |w| w[:id] }.uniq.size  # Has unique IDs
    assert_equal [10.50, 20.75], widgets.map { |w| w[:price] }  # Has prices
  end

  def test_auto_column_selection_for_custom_view
    blueprint = Class.new(Blueprinter::Base) do
      fields :id, :name
      view :custom do
        field :price
      end

      view :other_custom do
        field :description
      end
    end

    
    # Apply the extension to see what columns it selects
    optimized_q = @auto_column_selector.pre_render(@query, blueprint, :custom, {})
    
    # Verify it includes the expected columns (fields + foreign keys)
    selected_columns = optimized_q.values[:select].map(&:to_s).sort
    expected_columns = [
      'id', 'name', 'price',  # basic fields
    ].sort
    assert_equal expected_columns, selected_columns, "Should select fields for custom view"

    # Verify we're still optimizing (excluding unused columns like description)
    total_columns = Widget.column_names.size
    assert selected_columns.size < total_columns, "Should still optimize by excluding unused columns: #{selected_columns.size} < #{total_columns}"
    refute_includes selected_columns, 'description', "Should exclude unused description column"

    widgets = blueprint.render_as_hash(@query, view: :custom)

    # Should render successfully with optimized columns
    assert_equal ["Widget A", "Widget B"], widgets.map { |w| w[:name] }
    assert_equal 2, widgets.map { |w| w[:id] }.uniq.size  # Has unique IDs
    assert_equal [10.50, 20.75], widgets.map { |w| w[:price] }  # Has prices
  end

  def test_auto_column_selection_for_belongs_to_associations
    blueprint = Class.new(Blueprinter::Base) do
      fields :id, :name
      association :category, blueprint: CategoryBlueprint
      association :project, blueprint: ProjectBlueprint
      association :battery1, blueprint: BatteryBlueprint
      association :battery2, blueprint: BatteryBlueprint
    end
    
    # Apply the extension to see what columns it selects
    optimized_q = @auto_column_selector.pre_render(@query, blueprint, :default, {})
    
    # Verify it includes the expected columns (fields + foreign keys)
    selected_columns = optimized_q.values[:select].map(&:to_s).sort
    expected_columns = [
      'id', 'name', 
      'category_id', 
      'project_id', 
      'battery1_id', 'battery1_type', 
      'battery2_id', 'battery2_type'
    ].sort
    assert_equal expected_columns, selected_columns, "Should select fields and foreign keys for associations"
    
    # Verify we're still optimizing (excluding unused columns like [customer_id])
    total_columns = Widget.column_names.size
    assert selected_columns.size < total_columns, "Should still optimize by excluding unused columns: #{selected_columns.size} < #{total_columns}"
    refute_includes selected_columns, 'customer_id', "Should exclude unused customer_id column"
    
    widgets = blueprint.render_as_hash(@query, view: :default)

    # Should render successfully with associations
    assert_equal ["Foo", "Foo"], widgets.map { |w| w[:category][:name] }
    assert_equal ["Project A"], widgets.map { |w| w[:project][:name] }.uniq
    assert_equal ["100 parts Li ions, 100 parts other"], widgets.map { |w| w.dig(:battery1, :description) }.uniq
    assert_equal ["100 parts lead, 100 parts acid", nil], widgets.map { |w| w.dig(:battery2, :description) }.uniq
  end

  def test_column_selection_for_explicit_select_option
    blueprint = Class.new(Blueprinter::Base) do
      field :id
      field :name, select: :price
      field :formatted_description, select: :description do |widget|
        "Formatted: #{widget.description}"
      end
    end

    optimized_q = @auto_column_selector.pre_render(@query, blueprint, :default, {})
    
    # Verify only the expected columns were selected for default view
    selected_columns = optimized_q.values[:select].map(&:to_s).sort
    expected_columns = ['id', 'name', 'price', 'description'].sort
    assert_equal expected_columns, selected_columns, "Should select columns from field select option"
    
    # Verify we're not selecting ALL columns (should be less than total available)
    total_columns = Widget.column_names.size
    assert selected_columns.size < total_columns, "Should select fewer columns than total available: #{selected_columns.size} < #{total_columns}"

    widgets = blueprint.render_as_hash(@query)

    # Should render successfully with explicit select option
    assert_equal 2, widgets.size
    assert_equal ["Widget A", "Widget B"], widgets.map { |w| w[:name] }
    assert_equal ["Formatted: test widget", "Formatted: test widget"], widgets.map { |w| w[:formatted_description] }
  end

  def test_column_selection_ignores_fields_without_matching_columns
    blueprint = Class.new(Blueprinter::Base) do
      field :id
      field :price
      field :incorrect_column_name
    end
    
    optimized_q = @auto_column_selector.pre_render(@query, blueprint, :default, {})
        
    expected_columns = ['id', 'price'].sort
    assert_equal expected_columns, optimized_q.values[:select].map(&:to_s).sort, "Should only select columns that have field.name matching a database column"
  end

  def test_column_selection_raises_error_with_select_option_that_does_not_match_a_column
    blueprint = Class.new(Blueprinter::Base) do
      field :id
      field :price
      field :incorrect_column_name # non-existent column, ignored, could be a method on the model.
      field :incorrect_price_2, select: :incorrect_price_3 # non-existent column but specified in select, should raise an error
    end

    error = assert_raises(ArgumentError) { @auto_column_selector.pre_render(@query, blueprint, :default, {}) }
    assert_equal error.message, "Blueprint field incorrect_price_2 has explicit select option incorrect_price_3 that does not match a column on the model Widget"
  end

  def test_auto_column_selection_with_block_true
    true_block_column_selector = BlueprinterActiveRecord::ColumnSelector.new { |object| true }
    q = true_block_column_selector.pre_render(@query, WidgetBlueprint, :default, {})

    refute_nil true_block_column_selector.auto_proc
    assert q.values[:select].any?, "Query should have explicit select values when block returns true"
  end

  def test_auto_column_selection_with_block_false
    false_block_column_selector = BlueprinterActiveRecord::ColumnSelector.new { |object| false }
    q = false_block_column_selector.pre_render(@query, WidgetBlueprint, :default, {})

    refute_nil false_block_column_selector.auto_proc
    assert_nil q.values[:select], "Query should not be modified when block returns false"
  end

  def test_no_auto_column_selection
    manual_column_selector = BlueprinterActiveRecord::ColumnSelector.new(auto: false)
    q = manual_column_selector.pre_render(@query, WidgetBlueprint, :default, {})

    refute manual_column_selector.auto
    assert_nil q.values[:select], "Query should not be modified when auto is false"
  end

  def test_manual_select_blueprint_columns
    manual_column_selector = BlueprinterActiveRecord::ColumnSelector.new(auto: false)
    q = @query.select_blueprint_columns
    q = manual_column_selector.pre_render(q, WidgetBlueprint, :default, {})

    refute manual_column_selector.auto
    assert q.values[:select].any?, "Query should be optimized when select_blueprint_columns is called"
  end

  def test_auto_column_selection_for_custom_foreign_key
    blueprint = Class.new(Blueprinter::Base) do
      fields :id, :name
      association :vendor, blueprint: VendorBlueprint
    end
    
    optimized_q = @auto_column_selector.pre_render(@query, blueprint, :default, {})
    
    selected_columns = optimized_q.values[:select].map(&:to_s).sort
    expected_columns = ['id', 'name', 'supplier_id'].sort  # Custom FK: supplier_id not vendor_id
    assert_equal expected_columns, selected_columns, "Should select custom foreign key supplier_id for vendor association"

    widgets = blueprint.render_as_hash(@query, view: :default)
    
    # Should successfully render vendor association via custom foreign key
    assert_equal 2, widgets.size
    widget_a = widgets.find { |w| w[:name] == "Widget A" }
    assert_equal "ACME Supplies", widget_a.dig(:vendor, :name)
  end

  def test_auto_column_selection_for_composite_foreign_key
    blueprint = Class.new(Blueprinter::Base) do
      fields :id, :name  
      association :location, blueprint: LocationBlueprint
    end

    optimized_q = @auto_column_selector.pre_render(@query, blueprint, :default, {})
    
    selected_columns = optimized_q.values[:select].map(&:to_s).sort
    expected_columns = ['id', 'name', 'location_building_code', 'location_room_number'].sort
    assert_equal expected_columns, selected_columns, "Should select both composite foreign key columns for location"

    widgets = blueprint.render_as_hash(@query, view: :default)
    
    # Should successfully render location association via composite foreign key
    widget_a = widgets.find { |w| w[:name] == "Widget A" }
    assert_equal "Conference Room A", widget_a.dig(:location, :name)
  end

  # Test through associations (company through category, customer_projects through customer)
  def test_auto_column_selection_for_has_many_through_associations
    blueprint = Class.new(Blueprinter::Base) do
      fields :id, :name
      association :customer_projects, blueprint: ProjectBlueprint
    end
    
    optimized_q = @auto_column_selector.pre_render(@query, blueprint, :default, {})
    
    selected_columns = optimized_q.values[:select].map(&:to_s).sort
    expected_columns = ['id', 'name', 'customer_id'].sort  # FK for through associations
    assert_equal expected_columns, selected_columns, "Should select foreign keys for through associations"

    widgets = blueprint.render_as_hash(@query, view: :default)
    
    # Should successfully render through association
    assert_equal ["Project A"], widgets.map { |w| w[:customer_projects].map { |p| p[:name] } }.flatten.uniq
    assert_equal 2, widgets.size
  end

  def test_auto_column_selection_for_has_one_through_associations
    blueprint = Class.new(Blueprinter::Base) do
      fields :id, :name
      association :company, blueprint: CompanyBlueprint
    end
    
    optimized_q = @auto_column_selector.pre_render(@query, blueprint, :default, {})
    
    selected_columns = optimized_q.values[:select].map(&:to_s).sort
    expected_columns = ['id', 'name', 'category_id'].sort  # FK for through associations
    assert_equal expected_columns, selected_columns, "Should select foreign keys for through associations"

    widgets = blueprint.render_as_hash(@query, view: :default)
    
    # Should successfully render through association
    assert_equal ["Bar"], widgets.map { |w| w[:company][:name] }.uniq
  end
end 