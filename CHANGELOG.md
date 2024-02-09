### 0.5.0 (2024-01-26)

* Adds an "auto" mode that automatically preloads every Blueprint-rendered query
* Adds a "dynamic" mode that allows a single block to decide which Blueprint-rendered queries get preloaded
* Adds two logging extensions for gathering preload stats before and after implementing the Preloader extension

### 0.4.0 (2024-01-18)

* Remove the Blueprinter reflection and extension stubs
* Require Blueprinter >= 1.0

### 0.3.1 (2023-12-04)

* Switches to a real Blueprinter Extension
* Autodetects Blueprinter and view on render
* Allows using `:includes` or `:eager_load` instead of `:preload`

### 0.1.3 (2023-10-16)

* [BUGFIX] Stop preloading when we hit a dynamic blueprint

### 0.1.2 (2023-10-03)

* [BUGFIX] Associations from included views were being missed

### 0.1.1 (2023-09-29)

* [BUGFIX] Open up to all 0.x blueprinter versions

### 0.1.0 (2023-09-25)

* [BUGFIX] Associations weren't being found if they used a custom name (e.g. `association :widget, blueprint: WidgetBlueprint, name: :wdgt`)

## 0.0.1 (2023-09-20)

* Initial release
