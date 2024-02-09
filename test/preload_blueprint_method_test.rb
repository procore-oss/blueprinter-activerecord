# frozen_string_literal: true

require 'test_helper'

class PreloadBlueprintMethodTest < Minitest::Test
  def test_without
    q = Widget.order(:name).select("id, name")
    assert_nil q.preload_blueprint_method
  end

  def test_blueprinter_default
    q = Widget.preload_blueprint.order(:name).select("id, name")
    assert_equal :preload, q.preload_blueprint_method
  end

  def test_blueprinter_preload
    q = Widget.preload_blueprint(use: :preload).order(:name).select("id, name")
    assert_equal :preload, q.preload_blueprint_method
  end

  def test_blueprinter_includes
    q = Widget.all.preload_blueprint(use: :includes).order(:name).select("id, name")
    assert_equal :includes, q.preload_blueprint_method
  end

  def test_blueprinter_eager_load
    q = Widget.all.preload_blueprint(use: :eager_load).order(:name).select("id, name")
    assert_equal :eager_load, q.preload_blueprint_method
  end
end
