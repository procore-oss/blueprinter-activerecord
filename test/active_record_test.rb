# frozen_string_literal: true

require 'test_helper'
require 'stringio'

# NOTE These tests don't check any of THIS gem's code. They're sanity checks to ensure that new AR versions continue to behave as we expect them to.
class ActiveRecordTest < Minitest::Test
  def setup
    DatabaseCleaner.start
    customer = Customer.create!(name: "ACME")
    project = Project.create!(customer_id: customer.id, name: "Project A")
    category = Category.create!(name: "Foo")
    ref_plan = RefurbPlan.create!(name: "Plan A")
    battery1 = LiIonBattery.create!(num_ions: 100, num_other: 100, refurb_plan_id: ref_plan.id)
    battery2 = LeadAcidBattery.create!(num_lead: 100, num_acid: 100)
    Widget.create!(customer_id: customer.id, project_id: project.id, category_id: category.id, name: "Widget A", battery1: battery1, battery2: battery2)
    @io = StringIO.new
    ActiveRecord::Base.logger = Logger.new(@io)
  end

  def teardown
    DatabaseCleaner.clean
    ActiveRecord::Base.logger = nil
  end

  def test_that_preloads_deep_merge
    customers = Customer.
      preload({:projects => {:widgets => {:category => {}}}}).
      preload({:projects => {:widgets => [:battery1, :battery2]}}).
      strict_loading

    refute_nil customers[0].projects[0].widgets[0].category
    refute_nil customers[0].projects[0].widgets[0].battery1
    refute_nil customers[0].projects[0].widgets[0].battery2
  end

  def test_duplicate_preload_gets_join_loaded
    Customer.includes(:projects).references(:projects).preload(:projects).to_a
    @io.rewind
    lines = @io.readlines

    assert_match(/LEFT OUTER JOIN "projects"/, lines[0])
    assert_nil lines[1]
  end

  def test_duplicate_preload_is_ignored
    Customer.includes(:projects).preload(:projects).to_a
    @io.rewind
    lines = @io.readlines

    refute_match(/LEFT OUTER JOIN "projects"/, lines[0])
    assert_match(/FROM "projects"/, lines[1])
    assert_nil lines[2]
  end

  def test_a_more_complicated_duplication_case
    Customer.includes(:projects).references(:projects).preload(:projects => {:customer => :widgets}).to_a
    @io.rewind
    lines = @io.readlines

    assert_match(/LEFT OUTER JOIN "projects"/, lines[0])
    assert_match(/FROM "widgets"/, lines[1])
    assert_nil lines[2]
  end

  def test_invalid_associations_throw
    assert_raises { Widget.preload(foo).to_a }
  end

  def test_invalid_associations_under_polymorphic_works
    Widget.preload(battery1: {foo: :bar}).to_a
  end
end
