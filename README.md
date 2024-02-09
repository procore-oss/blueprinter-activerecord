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

### Look out for hidden associations

*blueprinter-activerecord* may feel magical, but it's not magic. Some associations may be "hidden" and you'll need to preload them the old-fashioned way.

```ruby
# Here's a Blueprint with one association and one field
class WidgetBlueprint < Blueprinter::Base
  association :category, blueprint: CategoryBlueprint
  field :parts_description
  ...
end

class Widget < ActiveRecord::Base
  belongs_to :category
  has_many :parts

  # The field is this instance method, and Blueprinter can't see inside it
  def parts_description
    # I'm calling the "parts" association but no one knows!
    parts.map(&:description).join(", ")
  end
end

q = Widget.where(...).order(...).
  # Since "category" is declared in the Blueprint, it will automatically be preloaded during "render".
  # But because "parts" is hidden inside of a method call, we must manually preload it.
  preload(:parts).
  # catch any other hidden associations
  strict_loading

WidgetBlueprint.render(q)
```

Rails 6.1 added support for `strict_loading`. Depending on your configuration, it will either raise exceptions or log warnings if a query triggers any lazy loading. Very useful for catching any associations Blueprinter can't see.

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
