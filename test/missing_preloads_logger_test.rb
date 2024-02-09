# frozen_string_literal: true

require 'test_helper'

class MissingPreloadsLoggerTest < Minitest::Test
  def setup
    @info = nil
    @ext = BlueprinterActiveRecord::MissingPreloadsLogger.new { |info| @info = info }
  end

  def test_finds_missing_preloads_without_preloader_ext
    q1 = Widget.where(category_id: 42).preload(:category)
    q2 = @ext.pre_render(q1, WidgetBlueprint, :short, {})

    refute_nil @info
    assert_equal Widget, @info.query.model
    assert_equal q1.to_sql, @info.query.to_sql
    assert_equal [
      "battery1",
      "battery1 > fake_assoc",
      "battery1 > refurb_plan",
      "battery2",
      "battery2 > fake_assoc",
      "battery2 > refurb_plan",
      "project",
      "project > customer",
    ], @info.found.map { |f| f.join " > " }
    assert_equal 89, @info.percent_found
  end

  def test_finds_visible_blueprints
    q = Project.preload(:widgets)
    @ext.pre_render(q, ProjectBlueprint, :extended, {})

    refute_nil @info
    assert_equal Project, @info.query.model
    assert_equal q.to_sql, @info.query.to_sql
    assert_equal [[:customer]], @info.visible
  end

  def test_finds_missing_preloads_with_dynamic_preloader_ext
    q1 = Widget.where(category_id: 42).preload(:category)
    q2 = BlueprinterActiveRecord::Preloader.new { false }.
      pre_render(q1, WidgetBlueprint, :short, {})
    q3 = @ext.pre_render(q2, WidgetBlueprint, :short, {})

    refute_nil @info
    assert_equal Widget, @info.query.model
    assert_equal q1.to_sql, @info.query.to_sql
    assert_equal [
      "battery1",
      "battery1 > fake_assoc",
      "battery1 > refurb_plan",
      "battery2",
      "battery2 > fake_assoc",
      "battery2 > refurb_plan",
      "project",
      "project > customer",
    ], @info.found.map { |f| f.join " > " }
    assert_equal 89, @info.percent_found
  end

  def test_ignores_queries_from_preloader_ext
    q1 = Widget.where(category_id: 42).preload(:category)
    q2 = BlueprinterActiveRecord::Preloader.new { true }.
      pre_render(q1, WidgetBlueprint, :short, {})
    q3 = @ext.pre_render(q2, WidgetBlueprint, :short, {})

    assert_equal Widget, q3.model
    assert_equal q1.to_sql, q3.to_sql
    assert_nil @info
  end
end
