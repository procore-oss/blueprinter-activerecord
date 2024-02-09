# frozen_string_literal: true

module BlueprinterActiveRecord
  #
  # A Blueprinter extension to log what preloads were found and added by the BlueprinterActiveRecord::Preloader extension.
  #
  # This extension may safely be used alongside the BlueprinterActiveRecord::MissingPreloadsLogger extension. Each query will
  # only be processed by one.
  #
  # NOTE Only queries that pass through a Blueprint's "render" method will be found.
  #
  #   Blueprinter.configure do |config|
  #     # The Preloader extension MUST be added first!
  #     config.extensions << BlueprinterActiveRecord::Preloader.new
  #
  #     config.extensions << BlueprinterActiveRecord::AddedPreloadsLogger.new do |info|
  #       next unless info.found.any?
  #
  #       Rails.logger.info({
  #         event: "added_preloads",
  #         root_model: info.query.model.name,
  #         sql: info.query.to_sql,
  #         added: info.found.map { |x| x.join " > " },
  #         percent_added: info.percent_found,
  #         trace: info.trace,
  #       }.to_json)
  #     end
  #   end
  #
  class AddedPreloadsLogger < Blueprinter::Extension
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
      if object.is_a?(ActiveRecord::Relation) && object.before_preload_blueprint
        from_code = object.before_preload_blueprint
        from_blueprint = Preloader.preloads(blueprint, view, object.model)
        info = PreloadInfo.new(object, from_code, from_blueprint, caller)
        @log_proc&.call(info)
      end
      object
    end
  end
end
