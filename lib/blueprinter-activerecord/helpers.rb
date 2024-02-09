# frozen_string_literal: true

module BlueprinterActiveRecord
  module Helpers
    extend self

    #
    # Combines all types of preloads (preload, includes, eager_load) into a single nested hash
    #
    # @param q [ActiveRecord::Relation]
    # @return [Hash] Symbol keys with Hash values of arbitrary depth
    #
    def extract_preloads(q)
      merge_values [*q.values[:preload], *q.values[:includes], *q.values[:eager_load]]
    end

    #
    # Count the number of preloads in a nested Hash.
    #
    # @param preloads [Hash] Nested Hash of preloads
    # @return [Integer] The number of associations in the Hash
    #
    def count_preloads(preloads)
      preloads.reduce(0) { |acc, (_key, val)|
        acc + 1 + count_preloads(val)
      }
    end

    #
    # Finds preloads from 'after' that are missing in 'before'.
    #
    # @param before [Hash] The extracted preloads from before Preloader ran
    # @param after [Hash] The extracted preloads from after Preloader ran
    # @param diff [Array<BlueprinterActiveRecord::MissingPreload>] internal use
    # @param path [Array<Symbol>] internal use
    # @return [Array<Array<Symbol>>] the preloads missing from 'before' . They're in a "path" structure, with the last element of each sub-array being the missing preload, e.g. `[[:widget], [:project, :company]]`
    #
    def diff_preloads(before, after, diff = [], path = [])
      after.each_with_object(diff) do |(key, after_val), obj|
        sub_path = path + [key]
        before_val = before[key]
        obj << sub_path if before_val.nil?
        diff_preloads(before_val || {}, after_val, diff, sub_path)
      end
    end

    #
    # Merges 'values', which may be any nested structure of arrays, hashes, strings, and symbols into a nested hash.
    #
    # @param value [Array|Hash|String|Symbol]
    # @param result [Hash]
    # @return [Hash] Symbol keys with Hash values of arbitrary depth
    #
    def merge_values(value, result = {})
      case value
      when Array
        value.each { |val| merge_values(val, result) }
      when Hash
        value.each { |key, val|
          key = key.to_sym
          result[key] ||= {}
          merge_values(val, result[key])
        }
      when Symbol
        result[value] ||= {}
      when String
        result[value.to_sym] ||= {}
      else
        raise ArgumentError, "Unexpected value of type '#{value.class.name}' (#{value.inspect})"
      end
      result
    end
  end
end
