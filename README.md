[![Discord](https://img.shields.io/badge/Chat-EDEDED?logo=discord)](https://discord.gg/PbntEMmWws)

# blueprinter-activerecord

*blueprinter-activerecord* is a [blueprinter](https://github.com/procore-oss/blueprinter) extension to help you easily preload associations from your Blueprints (N levels deep) and optimize your queries by selecting only the necessary columns. It also provides logging extensions so you can measure how effective these extensions are.

The two primary extensions are:
- **`Preloader`**: Automatically preloads ActiveRecord associations defined in your Blueprints.
- **`ColumnSelector`**: Intelligently selects only the database columns required by your Blueprint's fields, reducing data transfer and memory usage.

## Installation

Add `blueprinter-activerecord` to your Gemfile and enable the extension using one of the configurations below.

## Configurations

This section covers configurations for both `Preloader` and `ColumnSelector`.

### Preloader Extension

The `Preloader` extension automatically loads associated records to prevent N+1 query problems.

#### Automatic mode (Preloader)

In automatic mode, every query (`ActiveRecord::Relation`) passed to a Blueprint will automatically be preloaded during render.

```ruby
Blueprinter.configure do |config|
  config.extensions << BlueprinterActiveRecord::Preloader.new(auto: true)
end

# Preloading will always happen during render
widgets = Widget.where(...).order(...)
json = WidgetBlueprint.render(widgets)
```

If you'd prefer to use `includes` rather than `preload`, pass `use: :includes` to the initializer.

#### Dynamic mode (Preloader)

In dynamic mode, each query passed to a Blueprint is evaluated by the block. If it returns `true`, the query will be preloaded during render.

```ruby
Blueprinter.configure do |config|
  config.extensions << BlueprinterActiveRecord::Preloader.new do |q, blueprint, view, options|
    # examine q, q.model, blueprint, view, or options and return true or false
  end
end

# If the above block returns true for q (widgets), preloading will happen during render
widgets = Widget.where(...).order(...)
json = WidgetBlueprint.render(widgets)

```

If you'd prefer to use `includes` rather than `preload`, pass `use: :includes` to the initializer.

#### Manual mode (Preloader)

In manual mode, nothing happens automatically; you'll need to opt individual queries into preloading.

```ruby
Blueprinter.configure do |config|
  config.extensions << BlueprinterActiveRecord::Preloader.new
end
```

The `preload_blueprint` method is used to opt queries in:

```ruby
q = Widget.
  where(...).
  order(...).
  preload_blueprint

# preloading happens during "render"
json = WidgetBlueprint.render(q, view: :extended)
```

If you'd prefer to use `includes` or `eager_load` rather than `preload`, pass the `use` option:

```ruby
  preload_blueprint(use: :includes)
```

### ColumnSelector Extension

The `ColumnSelector` extension optimizes your database queries by automatically selecting only the columns that are actually used by your Blueprint for a given view. This can significantly reduce data transfer from the database and memory footprint in your Ruby application.

**Benefits:**
- **Reduced Data Transfer**: Fetches only necessary data, speeding up database interaction.
- **Lower Memory Usage**: ActiveRecord instantiates objects with fewer attributes.
- **Improved Performance**: Can lead to faster query execution and serialization.

#### Automatic mode (ColumnSelector)

In automatic mode, `ColumnSelector` will optimize column selection for every `ActiveRecord::Relation` passed to a Blueprint during render.

```ruby
Blueprinter.configure do |config|
  config.extensions << BlueprinterActiveRecord::ColumnSelector.new(auto: true)
end

# Column selection will always happen during render
widgets = Widget.where(...).order(...)
# SQL will be like: SELECT "widgets"."id", "widgets"."name", ... FROM "widgets"
json = WidgetBlueprint.render(widgets, view: :compact)
```

#### Dynamic mode (ColumnSelector)

In dynamic mode, `ColumnSelector` evaluates each query using the provided block. If the block returns `true`, column selection will be applied.

```ruby
Blueprinter.configure do |config|
  config.extensions << BlueprinterActiveRecord::ColumnSelector.new do |q, blueprint, view, options|
    # examine q, q.model, blueprint, view, or options and return true or false
  end
end

# Column selection will happen if the above block returns true
widgets = Widget.where(...).order(...)
json = WidgetBlueprint.render(widgets)
```

#### Manual mode (ColumnSelector)

In manual mode, `ColumnSelector` does nothing automatically. You need to explicitly opt-in queries for column selection using the `select_blueprint_columns` method on an `ActiveRecord::Relation`.

```ruby
Blueprinter.configure do |config|
  config.extensions << BlueprinterActiveRecord::ColumnSelector.new
end
```

Opt-in specific queries:
```ruby
q = Widget.
  where(...).
  order(...).
  select_blueprint_columns(WidgetBlueprint, :compact) # Specify Blueprint and view

# Column selection will be applied before rendering
json = WidgetBlueprint.render(q, view: :compact)
```

### Combining Preloader and ColumnSelector

`Preloader` and `ColumnSelector` are designed to work together seamlessly. For optimal performance and correctness, it's generally recommended to **configure `Preloader` before `ColumnSelector`**.

```ruby
Blueprinter.configure do |config|
  # 1. Preloader first: to identify associations and their foreign keys
  config.extensions << BlueprinterActiveRecord::Preloader.new(auto: true)
  # 2. ColumnSelector second: to select only needed columns, including foreign keys for preloads
  config.extensions << BlueprinterActiveRecord::ColumnSelector.new(auto: true)
end
```
This order ensures that:
1. `Preloader` determines which associations need to be loaded.
2. `ColumnSelector` then analyzes the blueprint to select the minimum set of columns.

## Annotations

Annotations help both extensions understand fields or associations that aren't straightforward.

### Preloader Annotations (`preload: ...`)

Sometimes a field in your blueprint is a method or block. `Preloader` can't "see" into methods or blocks, meaning it can't preload any associations inside. In these cases, annotate your blueprint so the extension knows what to preload.

```ruby
# Here is a model with some instance methods
class Widget < ActiveRecord::Base
  belongs_to :category
  belongs_to :project
  has_many :parts

  # Blueprinter can't see what this method is calling
  def parts_description
    # I'm calling the "parts" association, but the caller won't know!
    parts.map(&:description).join(", ")
  end
end

# Here's a Blueprint with one association, two annotated fields, and one annotated association
class WidgetBlueprint < Blueprinter::Base
  # This association will be automatically preloaded
  association :category, blueprint: CategoryBlueprint

  # Blueprinter can't see the "parts" association being used here, so we annotate it
  field :parts_description, preload: :parts

  # Your annotations can be as complex as needed
  field :owner_address, preload: {project: [:company, {owner: :address}]} do |widget|
    widget.project.owner ? widget.project.owner.address.to_s : widget.project.company.address
  end

  # You can annotate association blocks, too. "parts" is preloaded automatically.
  association :parts, blueprint: PartBlueprint, preload: :draft_parts do |widget|
    widget.parts + widget.draft_parts
  end
end
```

### ColumnSelector Annotations (`select: ...`)

Similarly, if a field in your blueprint accesses specific database columns that are not directly mapped as attributes or standard associations (e.g., through a method on the model that reads specific columns), you can guide `ColumnSelector` using the `select:` annotation.

This is **distinct** from `Preloader`'s `preload:` annotation.
- `preload: :association_name` tells `Preloader` to load an association.
- `select: [:column1, :column2]` tells `ColumnSelector` to ensure these specific columns are included in the `SELECT` statement for the primary model.

```ruby
class WidgetBlueprint < Blueprinter::Base
  identifier :id
  field :name
  field :description

  # Assume 'Widget' model has 'custom_field_a' and 'custom_field_b' in its table,
  # which are used by the 'computed_details' method but not defined as separate fields.
  field :computed_widget_details, select: [:custom_field_a, :custom_field_b] do |widget|
    widget.compute_details # method on Widget model that uses self.custom_field_a
  end
end

# When rendering WidgetBlueprint, ColumnSelector will ensure 'custom_field_a', 'custom_field_b'
# are included in the SELECT statement for the main query, in addition to 'id', 'name', etc.
```
**Note**: The `select:` annotation is for columns on the **primary model** (or its direct table) being blueprinted. Future enhancements may allow more granular control over association column selection.

## Recursive Blueprints

Sometimes a model, and its blueprint, will have recursive associations. Think of a nested Category model:

```ruby
class Category < ApplicationRecord
  belongs_to :parent, class_name: "Category", optional: true
  has_many :children, foreign_key: :parent_id, class_name: "Category", inverse_of: :parent
end

class CategoryBlueprint < Blueprinter::Base
  field :name
  association :children, blueprint: CategoryBlueprint
end
```

For these kinds of recursive blueprints, the extension will preload up to 10 levels deep by default. If this isn't enough, you can increase it:

```ruby
association :children, blueprint: CategoryBlueprint, max_recursion: 20
```

## Notes on use

### Pass the *query* to render, not query *results*

This is critical for both `Preloader` and `ColumnSelector`. If the query runs _before_ being passed to `render`, it's too late for either extension to modify it.

```ruby
widgets = Widget.where(...)
widgets.each { |widget| do_something wiget }
# too late to preload b/c the query already ran :(
WidgetBlueprint.render(widgets, view: :extended)
```

But sometimes you have no choice. In those cases, manually call `preload_blueprint` and pass it the Blueprint/view. Then preloading will happen as soon as the query runs.

```ruby
widgets = Widget.
  where(...).
  preload_blueprint(WidgetBlueprint, :extended)
# preloading will happen here, because it knows which Blueprint/view to look at
widgets.each { |widget| do_something wiget }
WidgetBlueprint.render(widgets, view: :extended)
```

### Also works for ActiveRecord::Associations::CollectionProxy

```ruby
project = Project.find(...)
WidgetBlueprint.render(project.widgets, view: :extended)
```

### Use strict_loading to find hidden associations

Rails 6.1 added support for `strict_loading`. Depending on your configuration, it will either raise exceptions or log warnings if a query triggers any lazy loading. Very useful for catching "hidden" associations.

```ruby
widgets = Widget.where(...).strict_loading
WidgetBlueprint.render(widgets)
```

## Logging

There are two different logging extensions available for `Preloader` You can use them together or separately to measure how much the Preloder extension is, or can, help your application. More specific logging for `ColumnSelector` may be added in the future.

### Missing Preloads Logger (For Preloader)

This extension is useful for measuring how helpful `BlueprinterActiveRecord::Preloader` will be for your application. It can be used with or without `Preloader`. Any Blueprint-rendered queries *not* caught by the `Preloader` extension will be caught by this logger.

```ruby
Blueprinter.configure do |config|
  # Preloader (optional) may be in in manual or dynamic mode
  config.extensions << BlueprinterActiveRecord::Preloader.new

  # Catches any Blueprint-rendered queries that aren't caught by Preloader
  config.extensions << BlueprinterActiveRecord::MissingPreloadsLogger.new do |info|
    Rails.logger.info({
      event: "missing_preloads",
      root_model: info.query.model.name,
      sql: info.query.to_sql,
      missing: info.found.map { |x| x.join " > " },
      percent_missing: info.percent_found,
      total: info.num_existing + info.found.size,
      visible: info.visible.size,
      trace: info.trace,
    }.to_json)
  end
end
```

### Added Preloads Logger (For Preloader)

This extension measures how many missing preloads are being found & fixed by the preloader. Any query caught by this extension *won't* end up in `MissingPreloadsLogger`.

```ruby
Blueprinter.configure do |config|
  # Preloader (required) may be in any mode
  config.extensions << BlueprinterActiveRecord::Preloader.new

  # Catches any queries found by Preloader
  config.extensions << BlueprinterActiveRecord::AddedPreloadsLogger.new do |info|
    Rails.logger.info({
      event: "added_preloads",
      root_model: info.query.model.name,
      sql: info.query.to_sql,
      added: info.found.map { |x| x.join " > " },
      percent_added: info.percent_found,
      total: info.num_existing + info.found.size,
      visible: info.visible.size,
      trace: info.trace,
    }.to_json)
  end
end
```

## Rake task

Curious what exactly `preload_blueprint` is going to preload? There's a rake task to pretty-print the whole tree. Pass it the Blueprint, view, and ActiveRecord model:

```bash
bundle exec rake blueprinter:activerecord:preloads[WidgetBlueprint,extended,Widget]
{
  :customer => {
    :contacts => {},
    :address => {},
  },
  :parts => {},
}
```

## Testing

```bash
bundle install
bundle exec appraisal install
bundle exec appraisal rake test
```
