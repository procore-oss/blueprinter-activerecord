class CustomerBlueprintV2 < Blueprinter::V2::Base
  fields :id, :name
end

class WidgetBlueprintV2 < Blueprinter::V2::Base
end

class ProjectBlueprintV2 < Blueprinter::V2::Base
  fields :id, :customer_id, :name

  view :extended do
    fields :id, :name
    object :customer, CustomerBlueprintV2
  end

  view :extended_plus do
    use :extended
  end

  view :extended_plus_with_widgets do
    use :extended_plus
    collection :widgets, WidgetBlueprintV2
  end
end

class CategoryBlueprintV2 < Blueprinter::V2::Base
  fields :id, :name

  view :extended do
    fields :id, :name, :description
  end

  view :nested do
    collection :children, CategoryBlueprintV2[:nested]
  end

  view :cyclic do
    collection :widgets, WidgetBlueprintV2[:cyclic]
  end
end

class RefurbPlanBlueprintV2 < Blueprinter::V2::Base
  fields :name, :description
end

class FakeAssocBlueprintV2 < Blueprinter::V2::Base
  fields :name
end

class BatteryBlueprintV2 < Blueprinter::V2::Base
  field :description do |battery, _opts|
    case battery
    when LiIonBattery
      "#{battery.num_ions} parts Li ions, #{battery.num_other} parts other"
    when LeadAcidBattery
      "#{battery.num_lead} parts lead, #{battery.num_acid} parts acid"
    end
  end
  object :refurb_plan, RefurbPlanBlueprintV2
  object :fake_assoc, FakeAssocBlueprintV2
end

class PartBlueprintV2 < Blueprinter::V2::Base
  fields :name
end

class WidgetBlueprintV2 < Blueprinter::V2::Base
  fields :id, :name, :price

  view :extended do
    fields :id, :name, :price, :description
    collection :parts, PartBlueprintV2
    object :category, CategoryBlueprintV2[:extended]
    object :project, ProjectBlueprintV2[:extended]
    object :battery1, BatteryBlueprintV2
    object :battery2, BatteryBlueprintV2
  end

  view :short do
    fields :id, :name, :price, :description
    collection :parts, PartBlueprintV2
    object :category, CategoryBlueprintV2[:extended]
    object :project, ProjectBlueprintV2[:extended]
    object :bat1, BatteryBlueprintV2, from: :battery1
    object :bat2, BatteryBlueprintV2, from: :battery2
  end

  view :no_power do
    fields :id, :name, :price, :description
    collection :parts, PartBlueprintV2
    object :category, CategoryBlueprintV2[:extended]
    object :project, ProjectBlueprintV2[:extended]
  end

  view :cyclic do
    object :category, CategoryBlueprintV2[:cyclic]
  end
end
