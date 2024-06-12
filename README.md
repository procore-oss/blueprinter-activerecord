[![Discord](https://img.shields.io/badge/Chat-EDEDED?logo=discord)](https://discord.gg/PbntEMmWws)

# blueprinter-activerecord

*blueprinter-activerecord* is a [blueprinter](https://github.com/procore-oss/blueprinter) extension to help you easily preload the associations from your Blueprints, N levels deep. It also provides logging extensions so you can measure how effective the primary extension is/will be.

## Installation

Add `blueprinter-activerecord` to your Gemfile and enable the extension using one of the configurations below.

## Configurations

### Automatic mode

In automatic mode, every query (`ActiveRecord::Relation`) passed to a Blueprint will automatically be preloaded during render.

```ruby
Blueprinter.configure do |config|
  config.extensions << BlueprinterActiveRecord::Preloader.new(auto: true)
end
```

If you'd prefer to use `includes` rather than `preload`, pass `use: :includes`.

### Dynamic mode

In dynamic mode, each query passed to a Blueprint is evaluated by the block. If it returns `true`, the query will be preloaded during render.

```ruby
Blueprinter.configure do |config|
  config.extensions << BlueprinterActiveRecord::Preloader.new do |q, blueprint, view, options|
    # examine q, q.model, blueprint, view, or options and return true or false
  end
end
```

If you'd prefer to use `includes` rather than `preload`, pass `use: :includes`.

### Manual mode

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

## Annotations

Sometimes a field in your blueprint is a method or block. This extension can't "see" into methods or blocks, meaning it can't preload any associations inside. In these cases, annotate your blueprint so the extension knows what to preload.

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

If the query runs before being passed to render, no preloading can take place.

```ruby
# Oops - the query already ran :(
widgets = Widget.where(...).to_a
WidgetBlueprint.render(widgets, view: :extended)

# Yay! :)
widgets = Widget.where(...)
WidgetBlueprint.render(widgets, view: :extended)
```

The query can also be an ActiveRecord::Associations::CollectionProxy:

```ruby
  project = Project.find(...)
  WidgetBlueprint.render(project.widgets, view: :extended)
```

If you **must** run the query first, there is a way:

```ruby
widgets = Widget.
  where(...).
  # preloading will happen HERE b/c we gave it all the info it needs
  preload_blueprint(WidgetBlueprint, :extended).
  to_a
do_something widgets
WidgetBlueprint.render(widgets, view: :extended)
```

### Use strict_loading to find hidden associations

Rails 6.1 added support for `strict_loading`. Depending on your configuration, it will either raise exceptions or log warnings if a query triggers any lazy loading. Very useful for catching "hidden" associations.

```ruby
widgets = Widget.where(...).strict_loading
WidgetBlueprint.render(widgets)
```

## Logging

There are two different logging extensions. You can use them together or separately to measure how much the Preloder extension is, or can, help your application.

### Missing Preloads Logger

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

### Added Preloads Logger

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
