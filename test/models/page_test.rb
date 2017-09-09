require 'test_helper'

class PageTest < ActiveSupport::TestCase
  test 'page urls should always have a protocol' do
    page = Page.create(url: 'www.example.com/whatever')
    assert_equal('http://www.example.com/whatever', page.url, 'The URL was not given a protocol')

    page = Page.create(url: 'https://www.example.com/whatever')
    assert_equal('https://www.example.com/whatever', page.url, 'The URL was modified unnecessarily')
  end

  test 'page urls without a domain should be invalid' do
    page = Page.create(url: 'some/path/to/a/page')
    assert_not(page.valid?, 'The page should be invalid because it has no domain')
  end

  test 'page title should sync with title from version with most recent capture time' do
    page = pages(:home_page)
    assert_equal('Page One', page.title)

    page.versions.create(title: 'Newest Version', capture_time: '2017-03-05T00:00:00Z')
    assert_equal('Newest Version', page.title, 'The page title should always sync against the title of the version with the most recent capture time')
    page.versions.create(title: 'Older Version', capture_time: '2017-03-01T00:00:00Z')
    refute_equal('Older Version', page.title, 'The page title should not sync against the title of a newly created version with an older capture time')
  end

  test "page title should not sync with a version's title if it's nil or blank" do
    page = pages(:home_page)
    assert_equal('Page One', page.title)

    page.versions.create(capture_time: '2017-03-05T00:00:00Z')
    assert_equal('Page One', page.title, 'The page title should not sync with the incoming version if it has a nil title')
    page.versions.create(title: '', capture_time: '2017-03-05T00:00:00Z')
    assert_equal('Page One', page.title, 'The page title should not sync with the incoming version if it has an empty title')
  end
end
