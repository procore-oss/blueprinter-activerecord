# frozen_string_literal: true

require 'test_helper'

class AddedPreloadsLoggerTest < Minitest::Test
  def setup
    @info = nil
    @ext = BlueprinterActiveRecord::AddedPreloadsLogger.new { |info| @info = info }
  end

  def test_adds_missing_preloads
    q1 = Widget.where(category_id: 42).preload(:category)
    q2 = BlueprinterActiveRecord::Preloader.new { true }.
      pre_render(q1, WidgetBlueprint, :short, {})
    q3 = @ext.pre_render(q2, WidgetBlueprint, :short, {})

    assert_equal({
      :category=>{},
      :battery1=>{:fake_assoc=>{}, :fake_assoc2=>{}, :refurb_plan=>{}},
      :battery2=>{:fake_assoc=>{}, :fake_assoc2=>{}, :refurb_plan=>{}},
      :project=>{:customer=>{}},
    }, BlueprinterActiveRecord::Helpers.extract_preloads(q3))

    refute_nil @info
    assert_equal Widget, @info.query.model
    assert_equal q1.to_sql, @info.query.to_sql
    assert_equal [
      "battery1",
      "battery1 > fake_assoc",
      "battery1 > fake_assoc2",
      "battery1 > refurb_plan",
      "battery2",
      "battery2 > fake_assoc",
      "battery2 > fake_assoc2",
      "battery2 > refurb_plan",
      "project",
      "project > customer",
    ], @info.found.map { |f| f.join " > " }
    assert_equal 91, @info.percent_found
  end

  def test_finds_visible_blueprints
    q = BlueprinterActiveRecord::Preloader.new { true }.
      pre_render(Project.preload(:widgets), WidgetBlueprint, :short, {})
    @ext.pre_render(q, ProjectBlueprint, :extended, {})

    refute_nil @info
    assert_equal Project, @info.query.model
    assert_equal q.to_sql, @info.query.to_sql
    assert_equal [[:customer]], @info.visible
  end

  def test_ignores_queries_not_from_preloader_ext
    q1 = Widget.where(category_id: 42).preload(:category)
    q2 = BlueprinterActiveRecord::Preloader.new { false }.
      pre_render(q1, WidgetBlueprint, :short, {})
    q3 = @ext.pre_render(q2, WidgetBlueprint, :short, {})

    assert_equal Widget, q3.model
    assert_equal q1.to_sql, q3.to_sql
    assert_nil @info
  end
end
