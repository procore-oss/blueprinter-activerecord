# frozen_string_literal: true

require 'test_helper'

class NestedRenderTest < Minitest::Test
  def setup
    DatabaseCleaner.start
    customer1 = Customer.create!(name: "ACME")
    customer2 = Customer.create!(name: "FOO")
    project1 = Project.create!(customer_id: customer1.id, name: "Project A")
    project2 = Project.create!(customer_id: customer2.id, name: "Project B")
    project3 = Project.create!(customer_id: customer2.id, name: "Project C")
    category1 = Category.create!(name: "Foo")
    category2 = Category.create!(name: "Bar")
    ref_plan = RefurbPlan.create!(name: "Plan A")
    battery1 = LiIonBattery.create!(num_ions: 100, num_other: 100, refurb_plan_id: ref_plan.id)
    battery2 = LeadAcidBattery.create!(num_lead: 100, num_acid: 100)
    Widget.create!(customer_id: customer1.id, project_id: project1.id, category_id: category1.id, name: "Widget A", battery1: battery1, battery2: battery2)
    Widget.create!(customer_id: customer1.id, project_id: project1.id, category_id: category2.id, name: "Widget B", battery1: battery1)
    Widget.create!(customer_id: customer2.id, project_id: project2.id, category_id: category1.id, name: "Widget C", battery1: battery1)
    Widget.create!(customer_id: customer2.id, project_id: project3.id, category_id: category1.id, name: "Widget C", battery1: battery1)
    Blueprinter.configure do |config|
      config.extensions << BlueprinterActiveRecord::Preloader.new(auto: true)
    end
    @queries = []
    @sub = ActiveSupport::Notifications.subscribe 'sql.active_record' do |_name, _started, _finished, _uid, data|
      @queries << data.fetch(:sql)
    end
    @test_customer = customer2
  end

  def teardown
    DatabaseCleaner.clean
    Blueprinter.configure do |config|
      config.extensions = []
    end
    ActiveSupport::Notifications.unsubscribe @sub
    @queries.clear
  end

  def test_queries_with_auto
    ProjectBlueprint.render(Project.all.strict_loading, view: :extended_plus_with_widgets)
    assert_equal [
      'SELECT "projects".* FROM "projects"',
      'SELECT "customers".* FROM "customers" WHERE "customers"."id" IN (?, ?)',
      'SELECT "widgets".* FROM "widgets" WHERE "widgets"."project_id" IN (?, ?, ?)',
    ], @queries
  end

  def test_queries_for_collection_proxies
    ProjectBlueprint.render(@test_customer.projects.strict_loading, view: :extended_plus_with_widgets)
    assert_equal [
      'SELECT "projects".* FROM "projects" WHERE "projects"."customer_id" = ?',
      'SELECT "widgets".* FROM "widgets" WHERE "widgets"."project_id" IN (?, ?)'
    ], @queries
  end

  def test_queries_with_auto_and_nested_render_and_manual_preloads
    widget_blueprint = Class.new(Blueprinter::Base) do
      association :category, blueprint: CategoryBlueprint
    end

    project_blueprint = Class.new(Blueprinter::Base) do
      association :customer, blueprint: CustomerBlueprint
      field :widgets do |project, options|
        widget_blueprint.render_as_hash(project.widgets)
      end
    end

    q = Project.all.preload(widgets: :category).strict_loading
    project_blueprint.render(q)
    assert_equal [
      'SELECT "projects".* FROM "projects"',
      'SELECT "widgets".* FROM "widgets" WHERE "widgets"."project_id" IN (?, ?, ?)',
      'SELECT "categories".* FROM "categories" WHERE "categories"."id" IN (?, ?)',
      'SELECT "customers".* FROM "customers" WHERE "customers"."id" IN (?, ?)',
    ], @queries
  end
end
