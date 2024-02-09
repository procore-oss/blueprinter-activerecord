# frozen_string_literal: true

module BlueprinterActiveRecord
  #
  # Info about preloads from a query that was run through a Blueprinter's render method.
  #
  # Used for logging by the BlueprinterActiveRecord::MissingPreloadsLogger and BlueprinterActiveRecord::AddedPreloadsLogger extensions.
  #
  class PreloadInfo
    include Helpers

    # @return [ActiveRecord::Relation] The base query
    attr_reader :query

    # @return [Array<String>] Stack trace to the query
    attr_reader :trace

    #
    # @param query [ActiveRecord::Relation] The query passed to "render"
    # @param from_code [Hash] Nested Hash of preloads, includes, and eager_loads that were present in query when passed to "render"
    # @param from_blueprint [Hash] Nested Hash of associations pulled from the Blueprint view
    # @param trace [Array<String>] Stack trace to query
    #
    def initialize(query, from_code, from_blueprint, trace)
      @query = query
      @from_code = from_code
      @from_blueprint = from_blueprint
      @trace = trace
    end

    # @return [Integer] The percent of total preloads found by BlueprinterActiveRecord
    def percent_found
      total = num_existing + found.size
      ((found.size / num_existing.to_f) * 100).round
    end

    # @return [Integer] The number of preloads, includes, and eager_loads that existed before BlueprinterActiveRecord was involved
    def num_existing
      @num_existing ||= count_preloads(hash)
    end

    # @return [Array<Array<Symbol>>] Array of "preload paths" (e.g. [[:project, :company]]) to missing preloads that could have been found & added by BlueprinterActiveRecord::Preloader
    def found
      @found ||= diff_preloads(@from_code, hash)
    end

    # @return [Array<Array<Symbol>>] Array of "preload paths" (e.g. [[:project, :company]]) from the blueprint that were visible to the preloader
    def visible
      @visible ||= diff_preloads({}, @from_blueprint)
    end

    # @return [Hash] Nested hash of all preloads, both manually added and auto found
    def hash
      @hash ||= merge_values [@from_code, @from_blueprint]
    end
  end
end
