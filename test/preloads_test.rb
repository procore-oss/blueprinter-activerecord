# frozen_string_literal: true

require 'test_helper'

class PreloadsTest < Minitest::Test
  def test_preload_with_model
    preloads = BlueprinterActiveRecord::Preloader.preloads(WidgetBlueprint, :extended, Widget)
    assert_equal({
      category: {},
      project: {customer: {}},
      battery1: {refurb_plan: {}, fake_assoc: {}},
      battery2: {refurb_plan: {}, fake_assoc: {}},
    }, preloads)
  end

  def test_preload_with_model_with_custom_names
    preloads = BlueprinterActiveRecord::Preloader.preloads(WidgetBlueprint, :short, Widget)
    assert_equal({
      category: {},
      project: {customer: {}},
      battery1: {refurb_plan: {}, fake_assoc: {}},
      battery2: {refurb_plan: {}, fake_assoc: {}},
    }, preloads)
  end

  def test_preload_sans_model
    preloads = BlueprinterActiveRecord::Preloader.preloads(WidgetBlueprint, :extended)
    assert_equal({
      parts: {},
      category: {},
      project: {customer: {}},
      battery1: {refurb_plan: {}, fake_assoc: {}},
      battery2: {refurb_plan: {}, fake_assoc: {}},
    }, preloads)
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

    preloads = BlueprinterActiveRecord::Preloader.preloads(blueprint, :default, Widget)
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

    preloads = BlueprinterActiveRecord::Preloader.preloads(blueprint, :default, Widget)
    assert_equal({
      project: {},
      category: {},
      battery1: {refurb_plan: {}},
    }, preloads)
  end
end
