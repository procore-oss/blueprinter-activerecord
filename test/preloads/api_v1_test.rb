# frozen_string_literal: true

require 'test_helper'

class PreloadsApiV1Test < Minitest::Test
  def test_preload_with_model
    preloads = BlueprinterActiveRecord::Preloads::ApiV1.preloads(WidgetBlueprint, :extended, model: Widget)
    assert_equal({
      category: {},
      project: {customer: {}},
      battery1: {refurb_plan: {}, fake_assoc: {}, fake_assoc2: {}},
      battery2: {refurb_plan: {}, fake_assoc: {}, fake_assoc2: {}},
    }, preloads)
  end

  def test_preload_with_model_with_custom_names
    preloads = BlueprinterActiveRecord::Preloads::ApiV1.preloads(WidgetBlueprint, :short, model: Widget)
    assert_equal({
      category: {},
      project: {customer: {}},
      battery1: {refurb_plan: {}, fake_assoc: {}, fake_assoc2: {}},
      battery2: {refurb_plan: {}, fake_assoc: {}, fake_assoc2: {}},
    }, preloads)
  end

  def test_preload_with_polymorphic_model
    preloads = BlueprinterActiveRecord::Preloads::ApiV1.preloads(WidgetBlueprint, :extended, model: :polymorphic)
    assert_equal({:battery1=>{:fake_assoc=>{}, :fake_assoc2=>{}, :refurb_plan=>{}}, :battery2=>{:fake_assoc=>{}, :fake_assoc2=>{}, :refurb_plan=>{}}, :category=>{}, :parts=>{}, :project=>{:customer=>{}}}, preloads)
  end

  def test_preload_with_annotated_fields
    blueprint = Class.new(Blueprinter::Base) do
      association :project, blueprint: ProjectBlueprint
      field :category_name, preload: :category do |w|
        w.category.name
      end
      field :refurb_plan, preload: {battery1: :refurb_plan} do |w|
        w.battery1&.refurb_plan&.name
      end
    end

    preloads = BlueprinterActiveRecord::Preloads::ApiV1.preloads(blueprint, :default, model: Widget)
    assert_equal({
      project: {},
      category: {},
      battery1: {refurb_plan: {}},
    }, preloads)
  end

  def test_preload_with_annotated_associations
    blueprint = Class.new(Blueprinter::Base) do
      association :project, blueprint: ProjectBlueprint
      association :category_name, blueprint: CategoryBlueprint, preload: :category do |w|
        w.category.name
      end
      association :refurb_plan, blueprint: RefurbPlanBlueprint, preload: {battery1: :refurb_plan} do |w|
        w.battery1&.refurb_plan&.name
      end
    end

    preloads = BlueprinterActiveRecord::Preloads::ApiV1.preloads(blueprint, :default, model: Widget)
    assert_equal({
      project: {},
      category: {},
      battery1: {refurb_plan: {}},
    }, preloads)
  end

  def test_preload_with_recursive_blueprint_default_max
    blueprint = Class.new(Blueprinter::Base) do
      association :children, blueprint: self
      association :widgets, blueprint: WidgetBlueprint
    end

    preloads = BlueprinterActiveRecord::Preloads::ApiV1.preloads(blueprint, :default, model: Category)
    expected = BlueprinterActiveRecord::Preloads::ApiV1::DEFAULT_MAX_RECURSION.times.
      reduce({widgets: {}, children: {}}) { |acc, _|
        {widgets: {}, children: acc}
      }
    assert_equal(expected, preloads)
  end

  def test_preload_with_recursive_blueprint_custom_max
    blueprint = Class.new(Blueprinter::Base) do
      association :children, blueprint: self, max_recursion: 5
      association :widgets, blueprint: WidgetBlueprint
    end

    preloads = BlueprinterActiveRecord::Preloads::ApiV1.preloads(blueprint, :default, model: Category)
    expected = 5.times.reduce({widgets: {}, children: {}}) { |acc, _|
      {widgets: {}, children: acc}
    }
    assert_equal(expected, preloads)
  end

  def test_preload_with_cyclic_blueprints_default_max
    preloads = BlueprinterActiveRecord::Preloads::ApiV1.preloads(CategoryBlueprint, :cyclic, model: Category)
    expected = BlueprinterActiveRecord::Preloads::ApiV1::DEFAULT_MAX_RECURSION.times.
      reduce({widgets: {}}) { |acc, _|
        {widgets: {category: acc}}
      }
    assert_equal(expected, preloads)
  end

  def test_halts_on_dynamic_blueprint
    preloads = BlueprinterActiveRecord::Preloads::ApiV1.preloads(WidgetBlueprint, :dynamic, model: Widget)
    assert_equal({category: {}}, preloads)
  end

  def test_cycle_detection1
    cycles, count = BlueprinterActiveRecord::Preloads::ApiV1.count_cycles(CategoryBlueprint, :default, {})
    assert_equal({"CategoryBlueprint/default" => 0}, cycles)
    assert_equal 0, count
  end

  def test_cycle_detection2
    cycles, count = BlueprinterActiveRecord::Preloads::ApiV1.count_cycles(CategoryBlueprint, :default, {
      "CategoryBlueprint/default" => 0,
    })
    assert_equal({"CategoryBlueprint/default" => 1}, cycles)
    assert_equal 1, count
  end

  def test_cycle_detection3
    cycles, count = BlueprinterActiveRecord::Preloads::ApiV1.count_cycles(WidgetBlueprint, :default, {
      "WidgetBlueprint/default" => 9,
      "CategoryBlueprint/foo" => 8,
    })
    assert_equal({"WidgetBlueprint/default" => 10, "CategoryBlueprint/foo" => 8}, cycles)
    assert_equal 10, count
  end
end
