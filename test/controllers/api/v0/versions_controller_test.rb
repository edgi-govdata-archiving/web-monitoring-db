require 'test_helper'

class Api::V0::VersionsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  def setup
    @original_store = Archiver.store
    @original_allowed_hosts = Archiver.allowed_hosts
  end

  def teardown
    Archiver.allowed_hosts = @original_allowed_hosts
    Archiver.store = @original_store
  end

  test 'can only list versions without auth if configured' do
    with_rails_configuration(:allow_public_view, true) do
      get(api_v0_page_versions_url(pages(:home_page)))
      assert_response :success
    end

    with_rails_configuration(:allow_public_view, false) do
      get(api_v0_page_versions_url(pages(:home_page)))
      assert_response :unauthorized

      user = users(:alice)
      sign_in user

      get(api_v0_page_versions_url(pages(:home_page)))
      assert_response :success

      user.update permissions: (user.permissions - [User::VIEW_PERMISSION])
      get(api_v0_page_versions_url(pages(:home_page)))
      assert_response :forbidden
    end
  end

  test 'can list versions' do
    sign_in users(:alice)
    get(api_v0_page_versions_url(pages(:home_page)))
    assert_response(:success)
    assert_equal('application/json', @response.media_type)
    body_json = JSON.parse(@response.body)
    assert(body_json.key?('links'), 'Response should have a "links" property')
    assert(body_json.key?('data'), 'Response should have a "data" property')
    assert(body_json.key?('meta'), 'Response should have a "meta" property')
    assert(body_json['data'].is_a?(Array), 'Data should be an array')
  end

  test 'can list versions independent of pages' do
    sign_in users(:alice)
    get api_v0_versions_url
    assert_response(:success)
    body_json = JSON.parse(@response.body)
    assert(body_json.key?('data'), 'Response should have a "data" property')
    assert(body_json['data'].is_a?(Array), 'Data should be an array')
  end

  test 'can sample versions for a page' do
    page = pages(:home_page)
    # These two should get grouped.
    page.versions.create({ body_hash: 'def', source_type: 'a', capture_time: '2022-01-02T10:00:00Z' })
    page.versions.create({ body_hash: 'abc', source_type: 'a', capture_time: '2022-01-02T09:00:00Z' })
    # This one should not.
    page.versions.create({ body_hash: 'ghi', source_type: 'a', capture_time: '2022-01-01T09:00:00Z' })
    page.versions.each(&:update_different_attribute)

    sign_in users(:alice)
    get(api_v0_page_versions_sampled_url(page, capture_time: '2021-12-01...2022-02-01'))
    assert_response(:success)
    assert_equal('application/json', @response.media_type)
    body_json = JSON.parse(@response.body)
    assert(body_json.key?('links'), 'Response should have a "links" property')
    assert(body_json.key?('data'), 'Response should have a "data" property')
    assert(body_json.key?('meta'), 'Response should have a "meta" property')
    assert(body_json['data'].is_a?(Array), 'Data should be an array')

    # Ensure we got the right sample groups and right sampled version.
    assert_equal(body_json['data'][0]['time'], '2022-01-02')
    assert_equal(body_json['data'][0]['version_count'], 2)
    # Should be the latest different version of the sample period.
    assert_equal(body_json['data'][0]['version']['body_hash'], 'def')
  end

  test 'can post a new version' do
    sign_in users(:alice)
    skip
    # page = pages(:home_page)
    # post(api_v0_page_versions_url(page), params: {
    #   {
    #     'capture_time': '2017-04-23T17:25:43.000Z',
    #     'body_url': 'https://edgi-wm-versionista.s3.amazonaws.com/versionista1/74304-6222353/version-10997815.html',
    #     'body_hash': 'f366e89639758cd7f75d21e5026c04fb1022853844ff471865004b3274059686',
    #     'source_type': 'versionista',
    #     'source_metadata': {
    #       'account': 'versionista1',
    #       'site_id': '74304',
    #       'page_id': '6222353',
    #       'version_id': '10997815',
    #       'url': 'https://versionista.com/74304/6222353/10997815/',
    #       'page_url': 'https://versionista.com/74304/6222353/',
    #       'has_content': true,
    #       'is_404_page': false,
    #       'diff_with_previousUrl': 'https://versionista.com/74304/6222353/10997815:10987625',
    #       'diff_with_firstUrl': 'https://versionista.com/74304/6222353/10997815:9434924',
    #       'diff_hash': '1b94199f9e2ac9a0b28b533a90b2126bf991a4350b473b0c35729cc4f7ade6e1',
    #       'diff_length': 18305
    #     }
    #   }
    # })
  end

  test 'can filter versions by hash' do
    sign_in users(:alice)
    target = versions(:page1_v1)
    get api_v0_page_versions_url(pages(:home_page), hash: target.body_hash)
    body_json = JSON.parse @response.body
    ids = body_json['data'].pluck 'uuid'

    assert_includes ids, target.uuid,
                    'Results did not include versions for the filtered hash'
  end

  test 'can filter versions by exact date' do
    sign_in users(:alice)
    get api_v0_page_versions_url(
      pages(:home_page),
      capture_time: '2017-03-01T00:00:00Z'
    )
    body_json = JSON.parse @response.body
    ids = body_json['data'].pluck 'uuid'

    assert_includes ids, versions(:page1_v1).uuid,
                    'Results did not include versions captured on the filtered date'
    assert_not_includes ids, versions(:page1_v2).uuid,
                        'Results included versions not captured on the filtered date'
  end

  test 'returns meaningful error for bad dates' do
    sign_in users(:alice)
    get api_v0_page_versions_url(
      pages(:home_page),
      capture_time: 'ugh'
    )
    assert_response :bad_request

    body_json = JSON.parse @response.body
    assert body_json.key?('errors'), 'Response should have an "errors" property'
    assert_match(/date/i, body_json['errors'][0]['title'],
                 'Error does not mention date')
  end

  test 'can filter versions by date range' do
    sign_in users(:alice)
    get api_v0_page_versions_url(
      pages(:home_page),
      capture_time: '2017-03-01T00:00:00Z..2017-03-01T12:00:00Z'
    )
    body_json = JSON.parse @response.body
    ids = body_json['data'].pluck 'uuid'

    assert_includes ids, versions(:page1_v1).uuid,
                    'Results did not include versions captured in the filtered date range'
    assert_not_includes ids, versions(:page1_v2).uuid,
                        'Results included versions not captured in the filtered date range'
  end

  test 'can filter versions captured before a date' do
    sign_in users(:alice)
    get api_v0_page_versions_url(
      pages(:home_page),
      capture_time: '..2017-03-01T12:00:00Z'
    )
    body_json = JSON.parse @response.body
    ids = body_json['data'].pluck 'uuid'

    assert_includes ids, versions(:page1_v1).uuid,
                    'Results did not include versions captured in the filtered date range'
    assert_not_includes ids, versions(:page1_v2).uuid,
                        'Results included versions not captured in the filtered date range'
  end

  test 'can filter versions captured after a date' do
    sign_in users(:alice)
    get api_v0_page_versions_url(
      pages(:home_page),
      capture_time: '2017-03-01T12:00:00Z..'
    )
    body_json = JSON.parse @response.body
    ids = body_json['data'].pluck 'uuid'

    assert_includes ids, versions(:page1_v2).uuid,
                    'Results did not include versions captured in the filtered date range'
    assert_not_includes ids, versions(:page1_v1).uuid,
                        'Results included versions not captured in the filtered date range'
  end

  test 'returns meaningful error for bad date ranges' do
    sign_in users(:alice)
    get api_v0_page_versions_url(
      pages(:home_page),
      capture_time: 'ugh..2017-03-04'
    )
    assert_response :bad_request

    body_json = JSON.parse @response.body
    assert body_json.key?('errors'), 'Response should have an "errors" property'
    assert_match(/date/i, body_json['errors'][0]['title'],
                 'Error does not mention date')
  end

  test 'can filter versions by source_type' do
    sign_in users(:alice)
    get api_v0_page_versions_url(pages(:home_page), source_type: 'pagefreezer')

    body_json = JSON.parse @response.body
    types = body_json['data'].collect { |v| v['source_type'] }.uniq

    assert_equal ['pagefreezer'], types, 'Got versions with wrong source_type'
  end

  test 'can retrieve a single version' do
    sign_in users(:alice)
    version = versions(:page1_v1)
    get api_v0_page_version_path(version.page, version)
    assert_response(:success)
    assert_equal('application/json', @response.media_type)
    body = JSON.parse(@response.body)
    assert(body.key?('links'), 'Response should have a "links" property')
    assert(body.key?('data'), 'Response should have a "data" property')
  end

  test 'can redirect when the raw response body for a single version is in ALLOWED_ARCHIVE_HOSTS' do
    Archiver.allowed_hosts = ['https://test-bucket.s3.amazonaws.com']
    sign_in users(:alice)
    version = versions(:page3_v1)
    get raw_api_v0_version_url(version)
    assert_response(:redirect)
  end

  test 'can return 404 when raw response body for a single version is missing' do
    Archiver.allowed_hosts = []
    sign_in users(:alice)
    version = versions(:page3_v1)
    get raw_api_v0_version_url(version)
    assert_response(:missing)
  end

  test 'can return 404 when body_url for raw response body is null' do
    Archiver.allowed_hosts = []
    sign_in users(:alice)
    version = versions(:page3_v2)
    get raw_api_v0_version_url(version)
    assert_response(:missing)
  end

  test 'can return raw response body for a single version in S3' do
    Archiver.allowed_hosts = []
    Archiver.store = FileStorage::S3.new(
      key: 'whatever',
      secret: 'test',
      bucket: 'test-bucket',
      region: 'us-west-2'
    )
    content = '<html>html content</html>'
    stub_request(:head, 'https://test-bucket.s3.us-west-2.amazonaws.com/page3_v1.html')
      .to_return(status: 200, body: '', headers: {})
    stub_request(:get, 'https://test-bucket.s3.us-west-2.amazonaws.com/page3_v1.html')
      .to_return(status: 200, body: content, headers: {})
    sign_in users(:alice)
    version = versions(:page3_v1)
    get raw_api_v0_version_url(version)
    assert_response(:success)
    assert_equal(content, @response.body)
  end

  test 'can return raw response body for a single version in local storage' do
    storage_path = Rails.root.join('tmp/test/storage')
    Archiver.allowed_hosts = []
    Archiver.store = FileStorage::LocalFile.new(path: storage_path)
    content = '<html>html content</html>'
    Archiver.store.save_file 'cb3a6ef0ccade26a4be5a3dfcb80ba2cc14f747bf2b38a7471866193bb9be14d', content
    sign_in users(:alice)
    version = versions(:page3_v3)
    get raw_api_v0_version_url(version)
    assert_response(:success)
    assert_equal(content, @response.body)
  end

  test 'can query by source_metadata fields' do
    sign_in users(:alice)
    version = versions(:page1_v1)
    get api_v0_versions_path(params: {
      source_metadata: { version_id: version.source_metadata['version_id'] }
    })

    assert_response(:success)
    body = JSON.parse(@response.body)
    ids = body['data'].collect { |v| v['source_metadata']['version_id'] }.uniq
    assert_equal(1, ids.length, 'Only one version ID should be included in results')
    assert_equal(
      version.source_metadata['version_id'],
      ids[0],
      'The returned version did not have a matching ID'
    )
  end

  test 'meta.total_results should be the total results across all chunks' do
    # For now, there no reasonable way to count versions in a reasonable amount
    # of time, so this functionality is disabled. This test is kept in case
    # the feature comes back (e.g. with clever caching of counts).
    skip

    sign_in users(:alice)
    page = pages(:home_page)

    get(api_v0_page_versions_url(page, params: { include_total: true }))
    assert_response(:success)
    assert_equal('application/json', @response.media_type)
    body_json = JSON.parse(@response.body)
    assert_equal(
      page.versions.count,
      body_json['meta']['total_results'],
      'Should contain the total number of versions mathcing the query for the page'
    )
  end

  test 'the ?include_total=true parameter is not supported' do
    sign_in users(:alice)
    page = pages(:home_page)

    get(api_v0_page_versions_url(page, params: { include_total: true }))
    assert_response(400)
    assert_equal('application/json', @response.media_type)
  end

  test 'can order versions with `?sort=field:direction`' do
    sign_in users(:alice)
    get(
      api_v0_versions_url(
        params: { sort: 'capture_time:asc' }
      )
    )
    assert_response(:success)
    body = JSON.parse(@response.body)
    assert_ordered_by(
      body['data'],
      [['capture_time']],
      name: 'Versions'
    )
  end

  test 'only lists versions that are different from the previous version' do
    now = Time.now
    page_versions = [
      { body_hash: 'abc', source_type: 'a', capture_time: now - 2.days },
      { body_hash: 'abc', source_type: 'b', capture_time: now - 1.9.days }
    ].collect { |data| pages(:home_page).versions.create(data) }
    page_versions.each(&:update_different_attribute)

    sign_in users(:alice)
    get(api_v0_versions_url)
    assert_response(:success)
    body = JSON.parse(@response.body)
    uuids = body['data'].collect { |version| version['uuid'] }

    assert_includes(uuids, page_versions[0].uuid)
    assert_not_includes(uuids, page_versions[1].uuid)
  end

  test 'lists versions regardless if different from the previous version if ?different=false' do
    now = Time.now
    page_versions = [
      { body_hash: 'abc', source_type: 'a', capture_time: now - 2.days },
      { body_hash: 'abc', source_type: 'b', capture_time: now - 1.9.days },
      { body_hash: 'abc', source_type: 'a', capture_time: now - 1.days },
      { body_hash: 'abc', source_type: 'b', capture_time: now - 0.9.days }
    ].collect { |data| pages(:home_page).versions.create(data) }
    page_versions.each(&:update_different_attribute)

    sign_in users(:alice)
    get(api_v0_versions_url(params: { different: false }))
    assert_response(:success)
    body = JSON.parse(@response.body)
    uuids = body['data'].collect { |version| version['uuid'] }

    assert_includes(uuids, page_versions[0].uuid)
    assert_includes(uuids, page_versions[1].uuid)
    assert_includes(uuids, page_versions[2].uuid)
    assert_includes(uuids, page_versions[3].uuid)
  end

  test 'filters by status using ?status=code' do
    sign_in users(:alice)
    get(api_v0_versions_url(params: { status: 404 }))
    assert_response(:success)
    body = JSON.parse(@response.body)
    assert(body['data'].all? { |item| item['status'] == 404 })
  end

  test 'filters by status interval using ?status=interval' do
    sign_in users(:alice)
    get(api_v0_versions_url(params: { status: '[400,500)' }))
    assert_response(:success)
    body = JSON.parse(@response.body)
    assert(body['data'].all? { |item| item['status'] >= 400 && item['status'] < 500 })
  end
end
