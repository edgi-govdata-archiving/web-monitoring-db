require 'test_helper'

class ApplicationRecordTest < ActiveSupport::TestCase
  test 'where_in_unbounded_range on an association should not return repeated primary model records' do
    pages = Page.where_in_unbounded_range(
      'versions.capture_time',
      [DateTime.parse('2017-01-01'), nil]
    ).pluck(:uuid).to_a

    unique_pages = pages.uniq
    assert_equal(unique_pages, pages, 'The same page was returned multiple times')
  end
end
