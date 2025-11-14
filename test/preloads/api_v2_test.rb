# frozen_string_literal: true

require 'test_helper'

class PreloadsApiV2Test < Minitest::Test
  def test_preload_with_model
    preloads = BlueprinterActiveRecord::Preloads::ApiV2.preloads(WidgetBlueprintV2[:extended], model: Widget)
    assert_equal({
      category: {},
      project: { customer: {} },
      battery1: { refurb_plan: {}, fake_assoc: {} },
      battery2: { refurb_plan: {}, fake_assoc: {} },
    }, preloads)
  end

  def test_preload_with_model_with_custom_names
    preloads = BlueprinterActiveRecord::Preloads::ApiV2.preloads(WidgetBlueprintV2[:short], model: Widget)
    assert_equal({
      category: {},
      project: { customer: {} },
      battery1: { refurb_plan: {}, fake_assoc: {} },
      battery2: { refurb_plan: {}, fake_assoc: {} },
    }, preloads)
  end

  def test_preload_with_polymorphic_model
    preloads = BlueprinterActiveRecord::Preloads::ApiV2.preloads(WidgetBlueprintV2[:extended], model: :polymorphic)
    assert_equal({:battery1=>{:fake_assoc=>{}, :refurb_plan=>{}}, :battery2=>{:fake_assoc=>{}, :refurb_plan=>{}}, :category=>{}, :parts=>{}, :project=>{:customer=>{}}}, preloads)
  end

  def test_preload_with_annotated_fields
    blueprint = Class.new(Blueprinter::V2::Base) do
      object :project, ProjectBlueprintV2
      field :category_name, preload: :category do |w|
        w.category.name
      end
      field :refurb_plan, preload: {battery1: :refurb_plan} do |w|
        w.battery1&.refurb_plan&.name
      end
    end

    preloads = BlueprinterActiveRecord::Preloads::ApiV2.preloads(blueprint, model: Widget)
    assert_equal({
      project: {},
      category: {},
      battery1: {refurb_plan: {}},
    }, preloads)
  end

  def test_preload_with_annotated_associations
    blueprint = Class.new(Blueprinter::V2::Base) do
      object :project, ProjectBlueprintV2
      object :category_name, CategoryBlueprintV2, preload: :category do |w|
        w.category.name
      end
      object :refurb_plan, RefurbPlanBlueprintV2, preload: {battery1: :refurb_plan} do |w|
        w.battery1&.refurb_plan&.name
      end
    end

    preloads = BlueprinterActiveRecord::Preloads::ApiV2.preloads(blueprint, model: Widget)
    assert_equal({
      project: {},
      category: {},
      battery1: {refurb_plan: {}},
    }, preloads)
  end

  def test_preload_with_recursive_blueprint_default_max
    blueprint = Class.new(Blueprinter::V2::Base) do
      collection :children, self
      collection :widgets, WidgetBlueprintV2
    end

    preloads = BlueprinterActiveRecord::Preloads::ApiV2.preloads(blueprint, model: Category)
    expected = BlueprinterActiveRecord::Preloads::ApiV2::DEFAULT_MAX_RECURSION.times.
      reduce({widgets: {}, children: {}}) { |acc, _|
        {widgets: {}, children: acc}
      }
    assert_equal(expected, preloads)
  end

  def test_preload_with_recursive_blueprint_custom_max
    blueprint = Class.new(Blueprinter::V2::Base) do
      collection :children, self, max_recursion: 5
      collection :widgets, WidgetBlueprintV2
    end

    preloads = BlueprinterActiveRecord::Preloads::ApiV2.preloads(blueprint, model: Category)
    expected = 5.times.reduce({widgets: {}, children: {}}) { |acc, _|
      {widgets: {}, children: acc}
    }
    assert_equal(expected, preloads)
  end

  def test_preload_with_cyclic_blueprints_default_max
    preloads = BlueprinterActiveRecord::Preloads::ApiV2.preloads(CategoryBlueprintV2[:cyclic], model: Category)
    expected = BlueprinterActiveRecord::Preloads::ApiV2::DEFAULT_MAX_RECURSION.times.
      reduce({widgets: {}}) { |acc, _|
        {widgets: {category: acc}}
      }
    assert_equal(expected, preloads)
  end

  def test_v1_interop
    widget_blueprint = Class.new(Blueprinter::V2::Base) do
      collection :category, CategoryBlueprint
    end
    preloads = BlueprinterActiveRecord::Preloads::ApiV2.preloads(widget_blueprint, model: Widget)
    assert_equal({ category: {} }, preloads)
  end

  def test_v1_interop_view_wrapper
    widget_blueprint = Class.new(Blueprinter::V2::Base) do
      collection :category, CategoryBlueprint[:extended]
    end
    preloads = BlueprinterActiveRecord::Preloads::ApiV2.preloads(widget_blueprint, model: Widget)
    assert_equal({ category: {} }, preloads)
  end

  def test_cycle_detection1
    cycles, count = BlueprinterActiveRecord::Preloads::ApiV2.count_cycles(CategoryBlueprintV2[:extended], {})
    assert_equal({ "CategoryBlueprintV2.extended" => 0 }, cycles)
    assert_equal 0, count
  end

  def test_cycle_detection2
    cycles, count = BlueprinterActiveRecord::Preloads::ApiV2.count_cycles(CategoryBlueprintV2[:extended], {
      "CategoryBlueprintV2.extended" => 0,
    })
    assert_equal({ "CategoryBlueprintV2.extended" => 1 }, cycles)
    assert_equal 1, count
  end

  def test_cycle_detection3
    cycles, count = BlueprinterActiveRecord::Preloads::ApiV2.count_cycles(WidgetBlueprintV2, {
      "WidgetBlueprintV2" => 9,
      "CategoryBlueprintV2.foo" => 8,
    })
    assert_equal({"WidgetBlueprintV2" => 10, "CategoryBlueprintV2.foo" => 8}, cycles)
    assert_equal 10, count
  end
end
