# frozen_string_literal: true

module Schema
  def self.load!
    ActiveRecord::Base.connection.instance_eval do
      create_table :customers do |t|
        t.string :name, null: false
      end

      create_table :projects do |t|
        t.integer :customer_id, null: false
        t.string :name, null: false
      end
      add_foreign_key :projects, :customers

      create_table :categories do |t|
        t.string :name, null: false
        t.text :description
      end

      create_table :widgets do |t|
        t.integer :customer_id, null: false
        t.integer :project_id, null: false
        t.integer :category_id, null: false
        t.string :name, null: false
        t.text :description
        t.decimal :price, precision: 6, scale: 2
        t.integer :battery1_id, null: false
        t.string :battery1_type, null: false
        t.integer :battery2_id
        t.string :battery2_type
      end
      add_foreign_key :widgets, :customers
      add_foreign_key :widgets, :projects
      add_foreign_key :widgets, :categories

      create_table :refurb_plans do |t|
        t.string :name, null: false
        t.text :description
      end

      create_table :lead_acid_batteries do |t|
        t.integer :refurb_plan_id
        t.integer :num_lead, null: false
        t.integer :num_acid, null: false
      end
      add_foreign_key :lead_acid_batteries, :refurb_plans

      create_table :li_ion_batteries do |t|
        t.integer :refurb_plan_id
        t.integer :num_ions, null: false
        t.integer :num_other, null: false
      end
      add_foreign_key :li_ion_batteries, :refurb_plans
    end
  end
end
