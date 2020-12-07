require 'test_helper'

class PageUrlTest < ActiveSupport::TestCase
  test 'PageUrls should always have a url_key' do
    page = Page.create(url: 'https://example.gov/')
    assert_not_empty(page.urls.first.url_key)

    new_url = page.urls.create(url: 'https://example.gov/some_page.html')
    assert_not_empty(new_url.url_key)
  end

  test 'PageUrls cannot change their url after saving' do
    page = Page.create(url: 'https://example.gov/')
    assert_raises(Exception) do
      page.urls.first.update(url: 'https://example2.gov/')
    end
  end

  test 'PageUrls are unique by page, url, from_time, to_time' do
    page = Page.create(url: 'https://example.gov/')
    assert_raises(ActiveRecord::RecordNotUnique) do
      page.urls.create(url: 'https://example.gov/')
    end
  end

  test 'PageUrls.current returns only records with matching from_time and to_time' do
    page = Page.create(url: 'https://example.gov/')
    page.urls.first.update(to_time: Time.now - 1.day)
    page.urls.create(url: 'https://example.gov/2', from_time: Time.now - 1.day)
    current = page.urls.current
    assert_equal(1, current.count)
    assert_equal('https://example.gov/2', current.first.url)
  end

  test 'PageUrls.current works with specified times instead of the current time' do
    page = Page.create(url: 'https://example.gov/')
    page.urls.first.update(to_time: Time.now - 1.day)
    page.urls.create(url: 'https://example.gov/2', from_time: Time.now - 1.day)
    current = page.urls.current(Time.now - 1.month)
    assert_equal(1, current.count)
    assert_equal('https://example.gov/', current.first.url)
  end
end
