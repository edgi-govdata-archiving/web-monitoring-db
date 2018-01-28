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
    refute(page.changed?, 'The page was left with unsaved changes')
    assert_equal('Newest Version', page.title, 'The page title should always sync against the title of the version with the most recent capture time')
    page.versions.create(title: 'Older Version', capture_time: '2017-03-01T00:00:00Z')
    refute(page.changed?, 'The page was left with unsaved changes')
    refute_equal('Older Version', page.title, 'The page title should not sync against the title of a newly created version with an older capture time')
  end

  test "page title should not sync with a version's title if it's nil or blank" do
    page = pages(:home_page)
    assert_equal('Page One', page.title)

    page.versions.create(capture_time: '2017-03-05T00:00:00Z')
    refute(page.changed?, 'The page was left with unsaved changes')
    assert_equal('Page One', page.title, 'The page title should not sync with the incoming version if it has a nil title')
    page.versions.create(title: '', capture_time: '2017-03-05T00:00:00Z')
    refute(page.changed?, 'The page was left with unsaved changes')
    assert_equal('Page One', page.title, 'The page title should not sync with the incoming version if it has an empty title')
  end

  test 'can add many maintainer models to a page' do
    pages(:home_page).add_maintainer(maintainers(:epa))
    pages(:home_page).add_maintainer(maintainers(:doi))
    assert pages(:home_page).maintainers.find(maintainers(:epa).uuid)
    assert pages(:home_page).maintainers.find(maintainers(:doi).uuid)
  end

  test 'can add a maintainer to a page by name' do
    pages(:home_page).add_maintainer('EPA')
    assert pages(:home_page).maintainers.find(maintainers(:epa).uuid)
  end

  test 'can add a maintainer case-insensitively' do
    pages(:home_page).add_maintainer('ePa')
    assert pages(:home_page).maintainers.find(maintainers(:epa).uuid)
  end

  test 'adding an unknown maintainer to a page creates that maintainer' do
    pages(:home_page).add_maintainer('Department of Unicorns')
    unicorns = Maintainer.find_by!(name: 'Department of Unicorns')
    assert pages(:home_page).maintainers.include?(unicorns)
  end

  test 'adding a maintainer repeatedly to a page does not cause errors or duplicates' do
    pages(:home_page).add_maintainer('EPA')
    pages(:home_page).add_maintainer(maintainers(:epa))

    assert_equal(1, pages(:home_page).maintainers.count)
  end
end
