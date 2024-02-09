# frozen_string_literal: true

class Customer < ActiveRecord::Base
  has_many :projects
  has_many :widgets, through: :projects
end

class Project < ActiveRecord::Base
  belongs_to :customer
  has_many :widgets
end

class Category < ActiveRecord::Base
  belongs_to :company
end

class Widget < ActiveRecord::Base
  Part = Struct.new(:name)

  belongs_to :customer
  belongs_to :project
  belongs_to :category
  belongs_to :battery1, polymorphic: true
  belongs_to :battery2, polymorphic: true

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
