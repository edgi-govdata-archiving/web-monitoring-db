require 'test_helper'

class Api::V0::PagesControllerTest < ActionDispatch::IntegrationTest
  test 'can list pages' do
    get '/api/v0/pages/'
    assert_response :success
    assert_equal 'application/json', @response.content_type
    body_json = JSON.parse @response.body
    assert body_json.key?('links'), 'Response should have a "links" property'
    assert body_json.key?('data'), 'Response should have a "data" property'
  end

  # Regression
  test 'should not include the `chunk` parameter multiple times in one paging link' do
    # This error occurred when the requested URL already had a `chunk` param
    get('/api/v0/pages?chunk=1')
    body = JSON.parse(@response.body)
    first_uri = URI.parse(body['links']['first'])
    assert_no_match(/(^|&)chunk=.+?&chunk=/, first_uri.query, 'The `chunk` param occurred multiple times in the same URL')
  end

  test 'should repect chunk_size pagination parameter' do
    # one result per page ('chunk' to avoid ambiguity with Page model)
    get(api_v0_pages_path, params: { chunk: 1, chunk_size: 1 })
    body = JSON.parse(@response.body)
    data = body['data']
    assert_equal 1, data.length
    # one result per page; second page
    get(api_v0_pages_path, params: { chunk: 2, chunk_size: 1 })
    body = JSON.parse(@response.body)
    data = body['data']
    assert_equal 1, data.length
    # two results per page
    get(api_v0_pages_path, params: { chunk: 1, chunk_size: 2 })
    body = JSON.parse(@response.body)
    data = body['data']
    assert_equal 2, data.length
  end

  test 'can filter pages by site' do
    site = 'http://example.com/'
    get "/api/v0/pages/?site=#{URI.encode_www_form_component site}"
    body_json = JSON.parse @response.body
    ids = body_json['data'].pluck 'uuid'

    assert_includes ids, pages(:home_page).uuid,
      'Results did not include pages for the filtered site'
    assert_not_includes ids, pages(:home_page_site2).uuid,
      'Results included pages not matching filtered site'
  end

  test 'can filter pages by agency' do
    agency = 'Department of Testing'
    get "/api/v0/pages/?agency=#{URI.encode_www_form_component agency}"
    body_json = JSON.parse @response.body
    ids = body_json['data'].pluck 'uuid'

    assert_includes ids, pages(:dot_home_page).uuid,
      'Results did not include pages for the filtered agency'
    assert_not_includes ids, pages(:home_page_site2).uuid,
      'Results included pages not matching filtered agency'
  end

  test 'can filter pages by title' do
    title = 'Page One'
    get api_v0_pages_path(title: title)
    body_json = JSON.parse @response.body
    ids = body_json['data'].pluck 'uuid'

    assert_includes ids, pages(:home_page).uuid,
      'Results did not include pages for the filtered site'
    assert_not_includes ids, pages(:home_page_site2).uuid,
      'Results included pages not matching filtered site'
  end

  test 'can filter pages by URL' do
    url = 'http://example.com/'
    get "/api/v0/pages/?url=#{URI.encode_www_form_component url}"
    body_json = JSON.parse @response.body
    ids = body_json['data'].pluck 'uuid'

    assert_includes ids, pages(:home_page).uuid,
      'Results did not include the page with the filtered URL'
    assert_not_includes ids, pages(:home_page_site2).uuid,
      'Results included pages not matching filtered URL'
    assert_not_includes ids, pages(:sub_page).uuid,
      'Results included pages with similar but not same filtered URL'
  end

  test 'can filter pages by URL with "*" wildcard' do
    url = 'http://example.com/*'
    get "/api/v0/pages/?url=#{URI.encode_www_form_component url}"
    body_json = JSON.parse @response.body
    ids = body_json['data'].pluck 'uuid'

    assert_includes ids, pages(:home_page).uuid,
      'Results did not include the page with the filtered URL'
    assert_includes ids, pages(:sub_page).uuid,
      'Results did not include the page with the filtered URL'
    assert_not_includes ids, pages(:home_page_site2).uuid,
      'Results included pages not matching filtered URL'
  end

  test 'can filter pages by version source_type' do
    get api_v0_pages_path(source_type: 'pagefreezer')
    body = JSON.parse @response.body
    ids = body['data'].pluck 'uuid'

    assert_includes ids, pages(:home_page).uuid,
      'Results did not include pages with versions captured by pagefreezer'
    assert_not_includes ids, pages(:home_page_site2).uuid,
      'Results included pages with versions not captured by pagreezer'
  end

  test 'can filter pages by version hash' do
    get api_v0_pages_path(hash: 'def')
    body = JSON.parse @response.body
    ids = body['data'].pluck 'uuid'

    assert_includes ids, pages(:sub_page).uuid,
      'Results did not include pages with versions matching the given hash'
    assert_not_includes ids, pages(:home_page_site2).uuid,
      'Results included pages with versions not matching the given hash'
  end

  test 'can filter pages by version capture_time' do
    get api_v0_pages_url(
      capture_time: '2017-03-01T00:00:00Z..2017-03-01T12:00:00Z'
    )
    body_json = JSON.parse @response.body
    ids = body_json['data'].pluck 'uuid'

    assert_includes ids, pages(:home_page).uuid,
      'Results did not include pages with versions captured in the filtered date range'
    assert_not_includes ids, pages(:home_page_site2).uuid,
      'Results included pages with versions not captured in the filtered date range'
  end

  test 'includes latest version if include_latest = true' do
    get api_v0_pages_path(include_latest: true)
    body = JSON.parse @response.body
    results = body['data']

    assert_kind_of Hash, results[0]['latest'], '"latest" property was not a hash'
  end

  test 'includes versions if include_versions = true' do
    get api_v0_pages_path(include_versions: true)
    body = JSON.parse @response.body
    results = body['data']

    # returned records should have "versions" instead of "latest"
    with_latest = results.select {|page| page.key? 'latest'}
    assert_empty with_latest, 'Results had objects with a "latest" property'

    assert_kind_of Array, results[0]['versions'], '"versions" property was not an array'

    home_page = results.find {|page| page['uuid'] == pages(:home_page).uuid}
    assert_equal pages(:home_page).versions.count, home_page['versions'].length,
      '"Home page" didn’t include all versions'
  end

  test 'includes only versions if include_versions = true and include_latest = true' do
    get api_v0_pages_path(include_versions: true, include_latest: true)
    body = JSON.parse @response.body
    results = body['data']

    # returned records should have "versions" instead of "latest"
    with_latest = results.select {|page| page.key? 'latest'}
    assert_empty with_latest, 'Results had objects with a "latest" property'
    assert_kind_of Array, results[0]['versions'], '"versions" property was not an array'
  end

  test 'Only includes versions that match query when include_versions = true' do
    get api_v0_pages_path(
      capture_time: '2017-03-01T00:00:00Z..2017-03-01T12:00:00Z',
      include_versions: true
    )
    body = JSON.parse @response.body
    results = body['data']

    home_page = results.find {|page| page['uuid'] == pages(:home_page).uuid}
    assert_equal 1, home_page['versions'].length, '"Home page" included too many versions'
  end

  test 'Included versions should be in descending capture_time order' do
    # Add a version whose natural order and capture_time order are different
    latest_time = pages(:home_page).versions.first.capture_time
    pages(:home_page).versions.create(capture_time: latest_time - 1.day)

    get api_v0_pages_path(
      include_versions: true,
      capture_time: '2017-01-01..',
      url: pages(:home_page).url
    )
    body = JSON.parse(@response.body)
    times = body['data'][0]['versions'].pluck('capture_time')
    assert_ordered(times.reverse, name: 'Versions')
  end

  test 'include_versions can be "1"' do
    get api_v0_pages_path(include_versions: 1)
    body = JSON.parse @response.body
    results = body['data']
    assert results.all? {|p| p.key? 'versions'}, 'Some pages did not have a "versions" property'
  end

  test 'include_versions can be "t"' do
    get api_v0_pages_path(include_versions: 't')
    body = JSON.parse @response.body
    results = body['data']
    assert results.all? {|p| p.key? 'versions'}, 'Some pages did not have a "versions" property'
  end

  test 'include_versions can be value-less (e.g. "pages?include_versions")' do
    get "#{api_v0_pages_path}?include_versions"
    body = JSON.parse @response.body
    results = body['data']
    assert results.all? {|p| p.key? 'versions'}, 'Some pages did not have a "versions" property'
  end

  test 'include_versions cannot be an empty string (e.g. "pages?include_versions")' do
    get "#{api_v0_pages_path}?include_versions="
    body = JSON.parse @response.body
    results = body['data']
    assert_not results.any? {|p| p.key? 'versions'}, 'Some pages have a "versions" property'
  end

  test 'includes environment in header of response' do
    get '/api/v0/pages/'
    assert_equal('test', @response.get_header('X-Environment'))
  end

  test 'does not return duplicate records when querying by version-specific parameters' do
    get api_v0_pages_path(source_type: 'versionista')
    body = JSON.parse(@response.body)

    page_ids = body['data'].pluck('uuid')
    assert_equal(page_ids.uniq, page_ids, 'The same page was returned multiple times')
  end

  test 'can retrieve a single page' do
    get api_v0_page_path(pages(:home_page))
    assert_response(:success)
    assert_equal('application/json', @response.content_type)
    body = JSON.parse(@response.body)
    assert(body.key?('data'), 'Response should have a "data" property')
  end

  test 'includes all pages when include_versions is true' do
    # This is a regression test for an issue where limit/offset queries for
    # paging wind up taking into account page-version combinations, not just
    # pages, so the actual page records on a given result page may not match up
    # with the full set.
    first_page = Page.first
    now = DateTime.now
    Page.transaction do
      100.times {|i| first_page.versions.create(capture_time: now - i.days)}

      (105 - Page.count).times do
        page = Page.create(url: "http://example.com/temp/#{SecureRandom.hex}")
        page.versions.create(capture_time: now - 1.day)
      end
    end

    def get_all_pages(url)
      get url
      assert_response(:success)
      body = JSON.parse @response.body
      pages = body['data']
      next_url = body['links']['next']
      next_url ? pages.concat(get_all_pages(next_url)) : pages
    end

    base_url = api_v0_pages_path(
      include_versions: true,
      capture_time: "..#{now.iso8601}"
    )
    found_ids = get_all_pages(base_url).collect {|page| page['uuid']}.sort
    all_ids = Page
      .where_in_unbounded_range('versions.capture_time', [nil, now])
      .pluck(:uuid)
      .sort

    assert_equal(
      all_ids,
      found_ids,
      "Not all page IDs were in paged results (#{found_ids.length} of #{all_ids.length} total found)"
    )
  end

  test 'the latest version is actually the latest' do
    # Add some versions out of order
    page = Page.first
    page.versions.create(capture_time: DateTime.now - 5.days)
    page.versions.create(capture_time: DateTime.now)
    page.versions.create(capture_time: DateTime.now - 1.day)
    page = Page.last
    page.versions.create(capture_time: DateTime.now - 5.days)
    page.versions.create(capture_time: DateTime.now)
    page.versions.create(capture_time: DateTime.now - 1.day)

    get api_v0_pages_path(
      capture_time: "..#{(DateTime.now - 1.day).iso8601}",
      include_latest: true
    )
    assert_response(:success)
    body = JSON.parse(@response.body)

    # Ensure every returned page has the correct latest version.
    body['data'].each do |found_page|
      actual_page = Page.find(found_page['uuid'])
      skip unless actual_page.latest

      assert_equal(
        actual_page.latest.capture_time.iso8601,
        found_page['latest']['capture_time']
      )
    end
  end
end
