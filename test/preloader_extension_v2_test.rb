# frozen_string_literal: true

require 'test_helper'

class PreloaderExtensionV2Test < Minitest::Test
  def setup
    DatabaseCleaner.start
    @customer = Customer.create!(name: "ACME")
    project = Project.create!(customer_id: @customer.id, name: "Project A")
    category = Category.create!(name: "Foo")
    ref_plan = RefurbPlan.create!(name: "Plan A")
    battery1 = LiIonBattery.create!(num_ions: 100, num_other: 100, refurb_plan_id: ref_plan.id)
    battery2 = LeadAcidBattery.create!(num_lead: 100, num_acid: 100)
    Widget.create!(customer_id: @customer.id, project_id: project.id, category_id: category.id, name: "Widget A", battery1: battery1, battery2: battery2)
    Widget.create!(customer_id: @customer.id, project_id: project.id, category_id: category.id, name: "Widget B", battery1: battery1)
    Widget.create!(customer_id: @customer.id, project_id: project.id, category_id: category.id, name: "Widget C", battery1: battery1)
    @widget_blueprint = Class.new(WidgetBlueprintV2) do
      extensions << BlueprinterActiveRecord::Preloader.new
    end
  end

  def teardown
    DatabaseCleaner.clean
  end

  def test_without
    q = Widget.
      where("name <> ?", "Widget C").
      order(:name)
    widgets = @widget_blueprint[:extended].render(q).to_hash

    assert_equal ["Widget A", 'Widget B'], widgets.map { |w| w[:name] }
    assert_equal ["Project A"], widgets.map { |w| w.dig(:project, :name) }.uniq
    assert_equal ["ACME"], widgets.map { |w| w.dig(:project, :customer, :name) }.uniq
    assert_equal ["Foo"], widgets.map { |w| w.dig(:category, :name) }.uniq
    assert_equal ["Plan A"], widgets.map { |w| [w.dig(:battery1, :refurb_plan, :name), w.dig(:battery1, :refurb_plan, :name)] }.flatten.compact.uniq
  end

  def test_blueprinter_default
    q = Widget.
      where("name <> ?", "Widget C").
      order(:name).
      preload_blueprint.
      strict_loading
    widgets = @widget_blueprint[:extended].render(q).to_hash

    assert_equal ["Widget A", 'Widget B'], widgets.map { |w| w[:name] }
    assert_equal ["Project A"], widgets.map { |w| w.dig(:project, :name) }.uniq
    assert_equal ["ACME"], widgets.map { |w| w.dig(:project, :customer, :name) }.uniq
    assert_equal ["Foo"], widgets.map { |w| w.dig(:category, :name) }.uniq
    assert_equal ["Plan A"], widgets.map { |w| [w.dig(:battery1, :refurb_plan, :name), w.dig(:battery1, :refurb_plan, :name)] }.flatten.compact.uniq
  end

  def test_blueprinter_preload
    q = Widget.
      where("name <> ?", "Widget C").
      order(:name).
      preload_blueprint(use: :preload).
      strict_loading
    widgets = @widget_blueprint[:extended].render(q).to_hash

    assert_equal ["Widget A", 'Widget B'], widgets.map { |w| w[:name] }
    assert_equal ["Project A"], widgets.map { |w| w.dig(:project, :name) }.uniq
    assert_equal ["ACME"], widgets.map { |w| w.dig(:project, :customer, :name) }.uniq
    assert_equal ["Foo"], widgets.map { |w| w.dig(:category, :name) }.uniq
    assert_equal ["Plan A"], widgets.map { |w| [w.dig(:battery1, :refurb_plan, :name), w.dig(:battery1, :refurb_plan, :name)] }.flatten.compact.uniq
  end

  def test_blueprinter_includes
    q = Widget.
      where("name <> ?", "Widget C").
      order(:name).
      preload_blueprint(use: :includes).
      strict_loading
    widgets = @widget_blueprint[:extended].render(q).to_hash

    assert_equal ["Widget A", 'Widget B'], widgets.map { |w| w[:name] }
    assert_equal ["Project A"], widgets.map { |w| w.dig(:project, :name) }.uniq
    assert_equal ["ACME"], widgets.map { |w| w.dig(:project, :customer, :name) }.uniq
    assert_equal ["Foo"], widgets.map { |w| w.dig(:category, :name) }.uniq
    assert_equal ["Plan A"], widgets.map { |w| [w.dig(:battery1, :refurb_plan, :name), w.dig(:battery1, :refurb_plan, :name)] }.flatten.compact.uniq
  end

  def test_blueprinter_eager_load
    q = Widget.
      where("widgets.name <> ?", "Widget C").
      order(:name).
      preload_blueprint(use: :eager_load).
      strict_loading
    widgets = @widget_blueprint[:no_power].render(q).to_hash

    assert_equal ["Widget A", 'Widget B'], widgets.map { |w| w[:name] }
    assert_equal ["Project A"], widgets.map { |w| w.dig(:project, :name) }.uniq
    assert_equal ["ACME"], widgets.map { |w| w.dig(:project, :customer, :name) }.uniq
    assert_equal ["Foo"], widgets.map { |w| w.dig(:category, :name) }.uniq
  end

  def test_blueprinter_preload_now
    q = Widget.
      where("widgets.name <> ?", "Widget C").
      order(:name).
      preload_blueprint(@widget_blueprint[:extended]).
      strict_loading

    assert_equal [{:battery1=>{:fake_assoc=>{}, :refurb_plan=>{}}, :battery2=>{:fake_assoc=>{}, :refurb_plan=>{}}, :category=>{}, :project=>{:customer=>{}}}], q.values[:preload]
  end

  def test_blueprinter_preload_now_with_existing_preloads
    q = Widget.
      where("widgets.name <> ?", "Widget C").
      order(:name).
      preload({battery1: :refurb_plan}).
      preload_blueprint(@widget_blueprint, :no_power).
      strict_loading

    assert_equal({:battery1=>{:refurb_plan=>{}}, :category=>{}, :project=>{:customer=>{}}}, BlueprinterActiveRecord::Helpers.merge_values(q.values[:preload]))
  end

  def test_auto_preload
    ext = BlueprinterActiveRecord::Preloader.new(auto: true)
    q = Widget.
      where("name <> ?", "Widget C").
      order(:name).
      strict_loading
    ctx = Blueprinter::V2::Context::Result.new(@widget_blueprint[:extended].new, [], {}, q, :json)
    ext.around_result(ctx) { |ctx| q = ctx.object }

    assert ext.auto
    assert_equal :preload, ext.use
    assert_equal [{:battery1=>{:fake_assoc=>{}, :refurb_plan=>{}}, :battery2=>{:fake_assoc=>{}, :refurb_plan=>{}}, :category=>{}, :project=>{:customer=>{}}}], q.values[:preload]
  end

  def test_auto_preload_with_existing_preloads
    ext = BlueprinterActiveRecord::Preloader.new(auto: true)
    q = Widget.
      where("name <> ?", "Widget C").
      order(:name).
      preload({battery1: :refurb_plan}).
      strict_loading
    ctx = Blueprinter::V2::Context::Result.new(@widget_blueprint[:no_power].new, [], {}, q, :json)
    ext.around_result(ctx) { |ctx| q = ctx.object }

    assert ext.auto
    assert_equal :preload, ext.use
    assert_equal({:battery1=>{:refurb_plan=>{}}, :category=>{}, :project=>{:customer=>{}}}, BlueprinterActiveRecord::Helpers.merge_values(q.values[:preload]))
  end

  def test_auto_preload_with_association_relation
    ext = BlueprinterActiveRecord::Preloader.new(auto: true)
    q = @customer.widgets.order(:name).strict_loading
    ctx = Blueprinter::V2::Context::Result.new(@widget_blueprint[:extended].new, [], {}, q, :json)
    ext.around_result(ctx) { |ctx| q = ctx.object }

    assert ext.auto
    assert_equal :preload, ext.use
    assert_equal [{:battery1=>{:fake_assoc=>{}, :refurb_plan=>{}}, :battery2=>{:fake_assoc=>{}, :refurb_plan=>{}}, :category=>{}, :project=>{:customer=>{}}}], q.values[:preload]
  end

  def test_auto_preload_with_block_true
    ext = BlueprinterActiveRecord::Preloader.new { |object| true }
    q = Widget.
      where("name <> ?", "Widget C").
      order(:name).
      strict_loading
    ctx = Blueprinter::V2::Context::Result.new(@widget_blueprint[:extended].new, [], {}, q, :json)
    ext.around_result(ctx) { |ctx| q = ctx.object }

    refute_nil ext.auto_proc
    assert_equal :preload, ext.use
    assert_equal [{:battery1=>{:fake_assoc=>{}, :refurb_plan=>{}}, :battery2=>{:fake_assoc=>{}, :refurb_plan=>{}}, :category=>{}, :project=>{:customer=>{}}}], q.values[:preload]
  end

  def test_auto_preload_with_block_false
    ext = BlueprinterActiveRecord::Preloader.new { |object| false }
    q = Widget.
      where("name <> ?", "Widget C").
      order(:name).
      strict_loading
    ctx = Blueprinter::V2::Context::Result.new(@widget_blueprint[:extended].new, [], {}, q, :json)
    ext.around_result(ctx) { |ctx| q = ctx.object }

    refute_nil ext.auto_proc
    assert_equal :preload, ext.use
    assert_nil q.values[:preload]
  end

  def test_auto_includes
    ext = BlueprinterActiveRecord::Preloader.new(auto: true, use: :includes)
    q = Widget.
      where("name <> ?", "Widget C").
      order(:name).
      strict_loading
    ctx = Blueprinter::V2::Context::Result.new(@widget_blueprint[:extended].new, [], {}, q, :json)
    ext.around_result(ctx) { |ctx| q = ctx.object }

    assert ext.auto
    assert_equal :includes, ext.use
    assert_equal [{:battery1=>{:fake_assoc=>{}, :refurb_plan=>{}}, :battery2=>{:fake_assoc=>{}, :refurb_plan=>{}}, :category=>{}, :project=>{:customer=>{}}}], q.values[:includes]
  end
end
