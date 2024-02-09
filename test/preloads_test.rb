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
end
