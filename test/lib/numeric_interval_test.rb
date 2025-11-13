# frozen_string_literal: true

require 'test_helper'

class NumericIntervalTest < ActiveSupport::TestCase
  test 'it parses closed intervals' do
    interval = NumericInterval.new('[1.1,2]')
    assert_equal(1.1, interval.start, 'Incorrect start value')
    assert_equal(2, interval.end, 'Incorrect end value')
    assert(!interval.start_open, 'Incorrect start_open value')
    assert(!interval.end_open, 'Incorrect end_open value')
  end

  test 'it parses open intervals' do
    interval = NumericInterval.new('(1.1,2)')
    assert_equal(1.1, interval.start, 'Incorrect start value')
    assert_equal(2, interval.end, 'Incorrect end value')
    assert(interval.start_open, 'Incorrect start_open value')
    assert(interval.end_open, 'Incorrect end_open value')
  end

  test 'it parses intervals with no start boundary' do
    interval = NumericInterval.new('(,2)')
    assert_nil(interval.start, 'Incorrect start value')
    assert_equal(2, interval.end, 'Incorrect end value')
    assert(interval.start_open, 'Incorrect start_open value')
    assert(interval.end_open, 'Incorrect end_open value')
  end

  test 'it parses intervals with no end boundary' do
    interval = NumericInterval.new('(1.1,)')
    assert_equal(1.1, interval.start, 'Incorrect start value')
    assert_nil(interval.end, 'Incorrect end value')
    assert(interval.start_open, 'Incorrect start_open value')
    assert(interval.end_open, 'Incorrect end_open value')
  end

  test 'it handles spaces in between' do
    interval = NumericInterval.new('(1.1, 2)')
    assert_equal(1.1, interval.start, 'Incorrect start value')
    assert_equal(2, interval.end, 'Incorrect end value')
    assert(interval.start_open, 'Incorrect start_open value')
    assert(interval.end_open, 'Incorrect end_open value')
  end

  test 'it handles spaces around the outside' do
    interval = NumericInterval.new(' (1.1, 2) ')
    assert_equal(1.1, interval.start, 'Incorrect start value')
    assert_equal(2, interval.end, 'Incorrect end value')
    assert(interval.start_open, 'Incorrect start_open value')
    assert(interval.end_open, 'Incorrect end_open value')
  end

  test 'it can be serialized' do
    interval = NumericInterval.new('(1.1, 2]')
    assert_equal('(1.1,2.0]', interval.to_s, 'Incorrect result for #to_s')
  end

  test 'it does not accept start >= end' do
    assert_raises(ArgumentError) {NumericInterval.new('[2,2]')}
    assert_raises(ArgumentError) {NumericInterval.new('[2,1]')}
  end

  test 'it does not accept no bounds at all' do
    assert_raises(ArgumentError) {NumericInterval.new('[,]')}
  end
end
