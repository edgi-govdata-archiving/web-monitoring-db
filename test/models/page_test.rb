require 'test_helper'

class PageTest < ActiveSupport::TestCase
  test 'page urls should always have a protocol' do
    page = Page.create(url: 'www.example1.com/whatever')
    assert_equal('http://www.example1.com/whatever', page.url, 'The URL was not given a protocol')

    page = Page.create(url: 'https://www.example1.com/whatever')
    assert_equal('https://www.example1.com/whatever', page.url, 'The URL was modified unnecessarily')
  end

  test 'page urls without a domain should be invalid' do
    page = Page.create(url: 'some/path/to/a/page')
    assert_not(page.valid?, 'The page should be invalid because it has no domain')
  end

  test 'page titles should be single lines with no outside spaces' do
    page = Page.create(url: 'example1.com/', title: "  This\nis the title\n  ")
    assert_equal('This is the title', page.title, 'The title was not normalized')
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

  test "page title should not sync with a version's title if the version was an error page" do
    page = pages(:home_page)
    assert_equal('Page One', page.title)

    page.versions.create(capture_time: '2017-03-05T00:00:00Z', status: 500, title: 'Page One v2')
    refute(page.changed?, 'The page was left with unsaved changes')
    assert_equal('Page One', page.title, 'The page title should not sync with the incoming version if it is an error status')
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

  test 'can add many tags to a page' do
    pages(:home_page).add_tag(tags(:listing_page))
    pages(:home_page).add_tag(tags(:frequently_updated))
    assert pages(:home_page).tags.find(tags(:listing_page).uuid)
    assert pages(:home_page).tags.find(tags(:frequently_updated).uuid)
  end

  test 'can add a tag to a page by name' do
    pages(:home_page).add_tag('Listing Page')
    assert pages(:home_page).tags.find(tags(:listing_page).uuid)
  end

  test 'can add a tag case-insensitively' do
    pages(:home_page).add_tag('lIStinG page')
    assert pages(:home_page).tags.find(tags(:listing_page).uuid)
  end

  test 'adding an unknown tag to a page creates that tag' do
    pages(:home_page).add_tag('Unicorns and rainbows')
    unicorns = Tag.find_by!(name: 'Unicorns and rainbows')
    assert pages(:home_page).tags.include?(unicorns)
  end

  test 'adding a tag repeatedly to a page does not cause errors or duplicates' do
    pages(:home_page_site2).add_tag('listing page')
    pages(:home_page_site2).add_tag(tags(:listing_page))

    assert_equal(1, pages(:home_page_site2).tags.count)
  end

  test 'a page can be untagged' do
    pages(:home_page_site2).add_tag('listing page')
    assert_equal(1, pages(:home_page_site2).tags.count)

    pages(:home_page_site2).untag('Listing Page')
    assert_equal(0, pages(:home_page_site2).tags.count)
  end

  test 'can list the names of tags' do
    pages(:home_page_site2).add_tag('listing page')
    pages(:home_page_site2).add_tag('frequently updated')
    assert_equal(
      ['Listing Page', 'Frequently Updated'],
      pages(:home_page_site2).tag_names
    )
  end

  test 'pages generate a url_key when created' do
    page = Page.create(url: 'http://sub.EXAMPLE.com/somewhere')
    assert_equal('com,example,sub)/somewhere', page.url_key)
  end

  test 'pages update url_key when url is changed' do
    page = Page.create(url: 'http://sub.EXAMPLE.com/somewhere')
    page.update(url: 'http://sub.EXAMPLE.com/elsewhere')
    assert_equal('com,example,sub)/elsewhere', page.url_key)
  end

  test 'page status must be a valid status code or nil' do
    page = pages(:home_page)
    page.status = nil
    assert(page.valid?, 'A nil status was not valid')

    page.status = 200
    assert(page.valid?, 'A 200 status was not valid')

    page.status = 1000
    assert_not(page.valid?, 'A 1000 status was valid')

    page.status = 'whats this now'
    assert_not(page.valid?, 'A text status was valid')
  end

  test 'pages tag themselves by domain or news when created' do
    new_page = Page.create(url: 'https://whatever.subdmain.noaa.gov/something')
    tags = new_page.tags.pluck(:name)
    assert_includes(tags, 'domain:whatever.subdmain.noaa.gov')
    assert_includes(tags, '2l-domain:noaa.gov')

    new_page_with_news = Page.create(url: 'https://whatever.subdmain.noaa/news/2')
    tags = new_page_with_news.tags.pluck(:name)
    assert_includes(tags, 'news')

    new_page_with_blog = Page.create(url: 'https://whatever.subdmain.noaa/blog/2')
    tags = new_page_with_blog.tags.pluck(:name)
    assert_includes(tags, 'news')

    new_page_with_press = Page.create(url: 'https://whatever.subdmain.noaa/press/2')
    tags = new_page_with_press.tags.pluck(:name)
    assert_includes(tags, 'news')
  end

  test 'pages can calculate their effective status code' do
    page = Page.create(url: 'https://example.gov/')
    page.versions.create(capture_time: Time.now - 15.days, status: 200)
    page.versions.create(capture_time: Time.now - 12.days, status: 500)
    page.versions.create(capture_time: Time.now - 10.days, status: 200)
    page.versions.create(capture_time: Time.now - 1.day, status: 404)
    assert_equal(page.update_status, 200, 'Status should be 200 when most of the timeframe was non-error versions')
  end

  test 'pages use the latest error code for their status when there is an error' do
    page = Page.create(url: 'https://example.gov/')
    page.versions.create(capture_time: Time.now - 15.days, status: 200)
    page.versions.create(capture_time: Time.now - 12.days, status: 500)
    page.versions.create(capture_time: Time.now - 10.days, status: 403)
    assert_equal(page.update_status, 403, 'Status should match the latest error code')

    page.latest.update(status: 404)
    assert_equal(page.update_status, 404, 'Status should match the latest error code')
  end

  test 'pages can calculate a status even when some versions have no status' do
    page = Page.create(url: 'https://example.gov/')
    page.versions.create(capture_time: Time.now - 12.days)
    assert_nil(page.update_status, 'Status should be nil if no versions have status')

    page.versions.create(capture_time: Time.now - 15.days, status: 200)
    assert_equal(page.update_status, 200, 'Status should be based only on versions with status codes')
  end

  test 'pages populate urls automatically' do
    page = Page.create(url: 'https://example.gov/')
    assert_equal(page.urls.count, 1, 'There should only be one URL for the page')
    assert_equal(page.urls.first.url, page.url)
    assert_equal(page.uuid, PageUrl.current.find_by_url(page.url).page_uuid, 'find_by_url() should return the page')
  end

  test 'pages populate urls when page.url is updated' do
    page = Page.create(url: 'https://example.gov/')
    assert_equal(page.urls.count, 1, 'There should only be one URL for the page')
    assert_equal(page.urls.first.url, page.url)

    page.update(url: 'https://www.example.gov/')
    assert_equal(page.urls.count, 2, 'There should be two URLs for the page after updating page.url')
    assert_includes(page.urls.pluck(:url), 'https://www.example.gov/', 'New URL should be in the page\'s list of URLs')

    page.update(url: 'https://example.gov/')
    assert_equal(page.urls.count, 2, 'Changing page.url back to a previous value should not add a new PageUrl')
  end

  test 'find_by_url matches by url_key if there is no URL match' do
    page = Page.create(title: 'Test Page', url: 'https://example.gov/some_page')
    found = Page.find_by_url('http://example.gov/some_page/')
    assert_equal(page, found)
  end

  test 'find_by_url prefers pages currently at the given URL' do
    url = 'https://example.gov/'
    old_page = Page.create(title: 'Old page', url:)
    old_page.urls.first.update(to_time: Time.now - 5.days)

    new_page = Page.create(title: 'New Page', url:)
    new_page.urls.first.update(from_time: Time.now - 5.days)

    older_page = Page.create(title: 'Ancient Page', url:)
    older_page.urls.first.update(to_time: Time.now - 10.days)

    assert_equal('New Page', Page.find_by_url('http://example.gov/').title)
  end

  test 'find_by_url returns latest non-current page if no current match is found' do
    url = 'https://example.gov/'
    old_page = Page.create(title: 'Old page', url:)
    old_page.urls.first.update(to_time: Time.now - 5.days)

    new_page = Page.create(title: 'New Page', url:)
    new_page.urls.first.update(to_time: Time.now - 2.days)

    older_page = Page.create(title: 'Ancient Page', url:)
    older_page.urls.first.update(to_time: Time.now - 10.days)

    assert_equal('New Page', Page.find_by_url('http://example.gov/').title)
  end

  test 'merge adds attributes and versions from another page' do
    now = Time.zone.now
    page1 = Page.create(title: 'First Page', url: 'https://example.gov/')
    page1.urls.create(url: 'https://example.gov/index.html')
    page1.add_tag('tag1')
    page1.add_tag('tag2')
    page1.add_maintainer('maintainer1')
    page1.add_maintainer('maintainer2')
    page1.versions.create(capture_time: now - 5.days, url: 'https://example.gov/', body_hash: 'abc')
    page1.versions.create(capture_time: now - 4.days, url: 'https://example.gov/', body_hash: 'abc')
    page1.versions.create(capture_time: now - 3.days, url: 'https://example.gov/index.html', body_hash: 'def', title: 'Title from p1 v3')

    page2 = Page.create(title: 'Second Page', url: 'https://example.gov/subpage')
    page2.urls.create(url: 'https://example.gov/')
    page2.add_tag('tag1')
    page2.add_tag('tag3')
    page2.add_maintainer('maintainer1')
    page2.add_maintainer('maintainer3')
    page2.versions.create(capture_time: now - 4.5.days, url: 'https://example.gov/subpage', body_hash: 'def')
    page2.versions.create(capture_time: now - 3.5.days, url: 'https://example.gov/subpage', body_hash: 'abc')
    page2.versions.create(capture_time: now - 2.5.days, url: 'https://example.gov/', body_hash: 'def', title: 'Title from p2 v3')
    page2_version_ids = page2.versions.collect(&:uuid)

    page1.merge(page2)
    assert_equal('Title from p2 v3', page1.title)
    assert_equal(['domain:example.gov', '2l-domain:example.gov', 'tag1', 'tag2', 'tag3'], page1.tags.pluck(:name))
    assert_equal(['maintainer1', 'maintainer2', 'maintainer3'], page1.maintainers.pluck(:name))
    assert_equal(3, page1.urls.count, 'Page1 has all the unique URLs from the pages')
    assert_equal(0, page2.urls.count, 'Page2 has no more URLs')
    # NOTE: depending on the system and on PG, there may be precision issues
    # data, so round before checking them.
    assert_equal(
      [
        [(now - 2.5.days).round, 'https://example.gov/', false],
        [(now - 3.0.days).round, 'https://example.gov/index.html', true],
        [(now - 3.5.days).round, 'https://example.gov/subpage', false],
        [(now - 4.0.days).round, 'https://example.gov/', true],
        [(now - 4.5.days).round, 'https://example.gov/subpage', true],
        [(now - 5.0.days).round, 'https://example.gov/', true]
      ],
      page1.versions.pluck(:capture_time, :url, :different)
        .map { |row| [row[0].round, row[1], row[2]] }
    )
    assert_raises(ActiveRecord::RecordNotFound) do
      Page.find(page2.uuid)
    end

    merge_record = MergedPage.find(page2.uuid)
    assert_equal(page1.uuid, merge_record.target.uuid)

    # Round the times, since precision seems to be lost in the DB.
    merge_audit = merge_record.audit_data
    merge_audit.update({
      'created_at' => Time.zone.parse(merge_audit['created_at']).round.as_json,
      'updated_at' => Time.zone.parse(merge_audit['updated_at']).round.as_json
    })
    assert_equal(
      {
        'uuid' => page2.uuid,
        'title' => 'Title from p2 v3',
        'url' => 'https://example.gov/subpage',
        'url_key' => 'gov,example)/subpage',
        'urls' => [
          { 'url' => 'https://example.gov/subpage', 'from_time' => nil, 'to_time' => nil, 'notes' => nil },
          { 'url' => 'https://example.gov/', 'notes' => nil, 'to_time' => nil, 'from_time' => nil }
        ],
        'tags' => ['domain:example.gov', '2l-domain:example.gov', 'tag1', 'tag3'],
        'maintainers' => ['maintainer1', 'maintainer3'],
        'versions' => page2_version_ids,
        'active' => true,
        'status' => nil,
        'created_at' => page2.created_at.round.as_json,
        'updated_at' => page2.updated_at.round.as_json
      },
      merge_audit
    )
  end

  test 'merging a page that was already merged into updates target references' do
    page1 = Page.create(title: 'First Page', url: 'https://example.gov/')
    page2 = Page.create(title: 'Second Page', url: 'https://example.gov/subpage')
    page3 = Page.create(title: 'Third Page', url: 'https://example.gov/another_page')

    page2.merge(page3)
    assert_equal(page2.uuid, MergedPage.find(page3.uuid).target_uuid)

    page1.merge(page2)
    assert_equal(page1.uuid, MergedPage.find(page3.uuid).target_uuid, 'Page 3 merge target was updated')
  end
end
