# frozen_string_literal: true

class Customer < ActiveRecord::Base
  has_many :projects
  has_many :widgets, through: :projects
end

class Company < ActiveRecord::Base
  has_many :categories
end

class Project < ActiveRecord::Base
  belongs_to :customer
  has_many :widgets
end

class Category < ActiveRecord::Base
  belongs_to :company
  belongs_to :parent, class_name: "Category", optional: true
  has_many :children, foreign_key: :parent_id, class_name: "Category", inverse_of: :parent
  has_many :widgets
end

class Widget < ActiveRecord::Base
  Part = Struct.new(:name)

  belongs_to :customer
  belongs_to :project
  belongs_to :category
  belongs_to :battery1, polymorphic: true
  belongs_to :battery2, polymorphic: true
  belongs_to :vendor, foreign_key: :supplier_id, optional: true
  
  # Composite foreign key association - handle Rails version differences
  if ActiveRecord.version >= Gem::Version.new("8.0.0")
    belongs_to :location, 
      foreign_key: [:location_building_code, :location_room_number],
      primary_key: [:building_code, :room_number],
      optional: true
  elsif ActiveRecord.version >= Gem::Version.new("7.1.1")
    belongs_to :location, 
      query_constraints: [:location_building_code, :location_room_number],
      primary_key: [:building_code, :room_number],
      optional: true
  end

  has_one :company, through: :category
  has_many :customer_projects, through: :customer, source: :projects

  def parts
    [Part.new('Part 1'), Part.new('Part 2')]
  end
end

class LeadAcidBattery < ActiveRecord::Base
  belongs_to :refurb_plan

  def fake_assoc
    {name: "Foo"}
  end

  def fake_assoc2
  end
end

class LiIonBattery < ActiveRecord::Base
  belongs_to :refurb_plan

  def fake_assoc
    {name: "Bar"}
  end

  def fake_assoc2
  end
end

class RefurbPlan < ActiveRecord::Base
end

class Vendor < ActiveRecord::Base
  has_many :widgets, foreign_key: :supplier_id
end

class Location < ActiveRecord::Base
  # Composite foreign key association - handle Rails version differences
  if ActiveRecord.version >= Gem::Version.new("8.0.0")
    has_many :widgets, 
      foreign_key: [:location_building_code, :location_room_number],
      primary_key: [:building_code, :room_number]
  else
    has_many :widgets, 
      query_constraints: [:location_building_code, :location_room_number],
      primary_key: [:building_code, :room_number]
  end
end
