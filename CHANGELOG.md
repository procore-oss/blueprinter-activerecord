### NEXT (?)

- Drop support for Ruby 3.0

### 1.3.0 (2024-09-04)

- Support ActiveRecord 7.2
- Remove restrictions on future ActiveRecord versions

### 1.2.0 (2024-06-26)

- [BUGFIX] Fixes an issue where an association wouldn't be preloaded if it used a dynamic blueprint.
- [BUGFIX] Fixes an infinite loop when [a Blueprint has an association to itself](https://github.com/procore-oss/blueprinter-activerecord/issues/13).
- Added the `max_recursion` option to customize the new default behavior for recursive/cyclic blueprints.
- Make `pre_render` compatible with all children of ActiveRecord::Relation ([#28](https://github.com/procore-oss/blueprinter-activerecord/pull/28)).

### 1.1.0 (2024-06-10)

- [FEATURE] Ability to annotate a field or association for extra preloads (e.g. `field :category_name, preload: :category`)

### 1.0.2 (2024-05-21)

- [BUGFIX] Fixes a potentially significant performance issue with `auto`. See https://github.com/procore-oss/blueprinter-activerecord/pull/16.

### 1.0.1 (2024-02-09)

- Fix gem summary

## 1.0.0 (2024-02-09)

- Initial release
