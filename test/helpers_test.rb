# frozen_string_literal: true

require 'test_helper'
require 'ostruct'

class HelpersTest < Minitest::Test
  def test_extract_preloads_empty
    q = Customer.all
    preloads = BlueprinterActiveRecord::Helpers.extract_preloads(q)
    assert_equal({}, preloads)
  end

  def test_extract_preloads_full
    q = Customer.preload(:widget).includes(project: :company).eager_load(:category)
    preloads = BlueprinterActiveRecord::Helpers.extract_preloads(q)
    assert_equal({
      category: {},
      project: {company: {}},
      widget: {},
    }, preloads)
  end

  def test_count_preloads
    count = BlueprinterActiveRecord::Helpers.count_preloads({
      a: {},
      b: {
        c: {
          d: {
            e: {},
          },
        },
        f: {
          h: {},
        },
      },
    })
    assert_equal 7, count
  end

  def test_diff_preloads
    before = {
      a: {},
      b: {
        b1: {},
      },
    }
    after = {
      a: {
        a1: { # missing
          a2: { # missing
            a3: {}, # missing
          },
        },
      },
      b: {
        b1: {
          b2: {}, # missing
        },
        b3: {}, # missing
      },
      c: {},
    }

    diff = BlueprinterActiveRecord::Helpers.diff_preloads(before, after)
    assert_equal [
      "a > a1",
      "a > a1 > a2",
      "a > a1 > a2 > a3",
      "b > b1 > b2",
      "b > b3",
      "c",
    ], diff.map { |d| d.join " > " }
  end

  def test_merge_values
    preloads = BlueprinterActiveRecord::Helpers.merge_values([
      :a,
      {b: [:c, {e: :f, g: {h: :i}}]},
      {j: [:k, :l], m: :n},
      [
        {j: {foo: :bar}},
      ],
      :b,
    ])

    assert_equal({
      a: {},
      b: {
        c: {},
        e: {
          f: {},
        },
        g: {
          h: {
            i: {},
          },
        },
      },
      j: {
        k: {},
        l: {},
        foo: {
          bar: {},
        },
      },
      m: {
        n: {},
      },
    }, preloads)
  end
end
