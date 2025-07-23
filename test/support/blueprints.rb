class CustomerBlueprint < Blueprinter::Base
  fields :id, :name
end

class WidgetBlueprint < Blueprinter::Base
end

class ProjectBlueprint < Blueprinter::Base
  fields :id, :customer_id, :name

  view :extended do
    fields :id, :name
    association :customer, blueprint: CustomerBlueprint
  end

  view :extended_plus do
    include_view :extended
  end

  view :extended_plus_with_widgets do
    include_view :extended_plus
    association :widgets, blueprint: WidgetBlueprint, view: :default
  end
end

class CategoryBlueprint < Blueprinter::Base
  fields :id, :name

  view :extended do
    fields :id, :name, :description
  end

  view :nested do
    association :children, blueprint: CategoryBlueprint, view: :nested
  end

  view :cyclic do
    association :widgets, blueprint: WidgetBlueprint, view: :cyclic
  end
end

class RefurbPlanBlueprint < Blueprinter::Base
  fields :name, :description
end

class FakeAssocBlueprint < Blueprinter::Base
  fields :name
end

class BatteryBlueprint < Blueprinter::Base
  field :description do |battery, _opts|
    case battery
    when LiIonBattery
      "#{battery.num_ions} parts Li ions, #{battery.num_other} parts other"
    when LeadAcidBattery
      "#{battery.num_lead} parts lead, #{battery.num_acid} parts acid"
    end
  end
  association :refurb_plan, blueprint: RefurbPlanBlueprint
  association :fake_assoc, blueprint: FakeAssocBlueprint
  association :fake_assoc2, blueprint: ->(obj) { obj.blueprint }
end

class PartBlueprint < Blueprinter::Base
  fields :name
end

class WidgetBlueprint < Blueprinter::Base
  fields :id, :name, :price

  view :extended do
    fields :id, :name, :price, :description
    association :parts, blueprint: PartBlueprint
    association :category, blueprint: CategoryBlueprint, view: :extended
    association :project, blueprint: ProjectBlueprint, view: :extended
    association :battery1, blueprint: BatteryBlueprint
    association :battery2, blueprint: BatteryBlueprint
  end

  view :short do
    fields :id, :name, :price, :description
    association :parts, blueprint: PartBlueprint
    association :category, blueprint: CategoryBlueprint, view: :extended
    association :project, blueprint: ProjectBlueprint, view: :extended
    association :battery1, blueprint: BatteryBlueprint, name: :bat1
    association :battery2, blueprint: BatteryBlueprint, name: :bat2
  end

  view :no_power do
    fields :id, :name, :price, :description
    association :parts, blueprint: PartBlueprint
    association :category, blueprint: CategoryBlueprint, view: :extended
    association :project, blueprint: ProjectBlueprint, view: :extended
  end

  view :cyclic do
    association :category, blueprint: CategoryBlueprint, view: :cyclic
  end

  view :dynamic do
    association :category, blueprint: -> { CategoryBlueprint }
  end
end

class VendorBlueprint < Blueprinter::Base
  fields :id, :name, :contact_email, :description
end

class LocationBlueprint < Blueprinter::Base
  fields :building_code, :room_number, :name
end

class CompanyBlueprint < Blueprinter::Base
  fields :id, :name, :description
end
