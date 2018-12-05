require 'test_helper'

class Api::V0::VersionsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test 'can list versions' do
    sign_in users(:alice)
    get(api_v0_page_versions_url(pages(:home_page)))
    assert_response(:success)
    assert_equal('application/json', @response.content_type)
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

  test 'can post a new version' do
    sign_in users(:alice)
    skip
    # page = pages(:home_page)
    # post(api_v0_page_versions_url(page), params: {
    #   {
    #     'capture_time': '2017-04-23T17:25:43.000Z',
    #     'uri': 'https://edgi-versionista-archive.s3.amazonaws.com/versionista1/74304-6222353/version-10997815.html',
    #     'version_hash': 'f366e89639758cd7f75d21e5026c04fb1022853844ff471865004b3274059686',
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
    get api_v0_page_versions_url(pages(:home_page), hash: target.version_hash)
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
    types = body_json['data'].collect {|v| v['source_type']}.uniq

    assert_equal ['pagefreezer'], types, 'Got versions with wrong source_type'
  end

  test 'can retrieve a single version' do
    sign_in users(:alice)
    version = versions(:page1_v1)
    get api_v0_page_version_path(version.page, version)
    assert_response(:success)
    assert_equal('application/json', @response.content_type)
    body = JSON.parse(@response.body)
    assert(body.key?('links'), 'Response should have a "links" property')
    assert(body.key?('data'), 'Response should have a "data" property')
  end

  test 'can query by source_metadata fields' do
    sign_in users(:alice)
    version = versions(:page1_v1)
    get api_v0_versions_path(params: {
      source_metadata: { version_id: version.source_metadata['version_id'] }
    })

    assert_response(:success)
    body = JSON.parse(@response.body)
    ids = body['data'].collect {|v| v['source_metadata']['version_id']}.uniq
    assert_equal(1, ids.length, 'Only one version ID should be included in results')
    assert_equal(
      version.source_metadata['version_id'],
      ids[0],
      'The returned version did not have a matching ID'
    )
  end

  test 'meta property should have a total_results field that contains total results across all chunks' do
    sign_in users(:alice)
    page = pages(:home_page)

    get(api_v0_page_versions_url(page))
    assert_response(:success)
    assert_equal('application/json', @response.content_type)
    body_json = JSON.parse(@response.body)
    assert_equal(
      page.versions.count,
      body_json['meta']['total_results'],
      'Should contain the total number of versions mathcing the query for the page'
    )
  end

  test 'can order versions with `?sort=field:direction,field:direction`' do
    sign_in users(:alice)
    get(
      api_v0_versions_url(
        params: { sort: 'source_type:asc, capture_time:asc' }
      )
    )
    assert_response(:success)
    body = JSON.parse(@response.body)
    assert_ordered_by(
      body['data'],
      [['source_type'], ['capture_time']],
      name: 'Versions'
    )
  end

  test 'only lists versions that are different from the previous version' do
    now = Time.now
    page_versions = [
      { version_hash: 'abc', source_type: 'a', capture_time: now - 2.days },
      { version_hash: 'abc', source_type: 'b', capture_time: now - 1.9.days }
    ].collect {|data| pages(:home_page).versions.create(data)}
    page_versions.each(&:update_different_attribute)

    sign_in users(:alice)
    get(api_v0_versions_url)
    assert_response(:success)
    body = JSON.parse(@response.body)
    uuids = body['data'].collect {|version| version['uuid']}

    assert_includes(uuids, page_versions[0].uuid)
    assert_not_includes(uuids, page_versions[1].uuid)
  end

  test 'lists versions regardless if different from the previous version if ?different=false' do
    now = Time.now
    page_versions = [
      { version_hash: 'abc', source_type: 'a', capture_time: now - 2.days },
      { version_hash: 'abc', source_type: 'b', capture_time: now - 1.9.days },
      { version_hash: 'abc', source_type: 'a', capture_time: now - 1.days },
      { version_hash: 'abc', source_type: 'b', capture_time: now - 0.9.days }
    ].collect {|data| pages(:home_page).versions.create(data)}
    page_versions.each(&:update_different_attribute)

    sign_in users(:alice)
    get(api_v0_versions_url(params: { different: false }))
    assert_response(:success)
    body = JSON.parse(@response.body)
    uuids = body['data'].collect {|version| version['uuid']}

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
    assert(body['data'].all? {|item| item['status'] == 404})
  end

  test 'filters by status interval using ?status=interval' do
    sign_in users(:alice)
    get(api_v0_versions_url(params: { status: '[400,500)' }))
    assert_response(:success)
    body = JSON.parse(@response.body)
    assert(body['data'].all? {|item| item['status'] >= 400 && item['status'] < 500})
  end
end
