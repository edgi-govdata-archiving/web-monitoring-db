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
end
