# frozen_string_literal: true

module BlueprinterActiveRecord
  #
  # A Blueprinter extension to log what COULD have been preloaded with the BlueprinterActiveRecord::Preloader extension.
  #
  # This extension may safely be used alongside the BlueprinterActiveRecord::Preloader and BlueprinterActiveRecord::AddedPreloadsLogger
  # extensions. Any queries processed by those extensions will be ignored by this one.
  #
  # NOTE Only queries that pass through a Blueprint's "render" method will be found.
  #
  #   Blueprinter.configure do |config|
  #     config.extensions << BlueprinterActiveRecord::MissingPreloadsLogger.new do |info|
  #       next unless info.found.any?
  #
  #       Rails.logger.info({
  #         event: "missing_preloads",
  #         root_model: info.query.model.name,
  #         sql: info.query.to_sql,
  #         missing: info.found.map { |x| x.join " > " },
  #         percent_missing: info.percent_found,
  #         trace: info.trace,
  #       }.to_json)
  #     end
  #   end
  #
  class MissingPreloadsLogger < Blueprinter::Extension
    include Helpers

    #
    # Initialize and configure the extension.
    #
    # @yield [BlueprinterActiveRecord::PreloadInfo] Your logging action
    #
    def initialize(&log_proc)
      @log_proc = log_proc
    end

    def pre_render(object, blueprint, view, options)
      if object.is_a?(ActiveRecord::Relation) && !object.before_preload_blueprint
        from_code = extract_preloads object
        from_blueprint = Preloader.preloads(blueprint, view, model: object.model)
        info = PreloadInfo.new(object, from_code, from_blueprint, caller)
        @log_proc&.call(info)
      end
      object
    end
  end
end
