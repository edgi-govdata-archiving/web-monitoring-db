require 'test_helper'

class Api::V0::VersionsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test 'can list versions' do
    get(api_v0_page_versions_url(pages(:home_page)))
    assert_response(:success)
    assert_equal('application/json', @response.content_type)
    body_json = JSON.parse(@response.body)
    assert(body_json.key?('links'), 'Response should have a "links" property')
    assert(body_json.key?('data'), 'Response should have a "data" property')
    assert(body_json['data'].is_a?(Array), 'Data should be an array')
  end

  test 'can list versions independent of pages' do
    get api_v0_versions_url
    assert_response(:success)
    body_json = JSON.parse(@response.body)
    assert(body_json.key?('data'), 'Response should have a "data" property')
    assert(body_json['data'].is_a?(Array), 'Data should be an array')
  end

  test 'can post a new version' do
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
    target = versions(:page1_v1)
    get api_v0_page_versions_url(pages(:home_page), hash: target.version_hash)
    body_json = JSON.parse @response.body
    ids = body_json['data'].pluck 'uuid'

    assert_includes ids, target.uuid,
      'Results did not include versions for the filtered hash'
  end

  test 'can filter versions by exact date' do
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
    get api_v0_page_versions_url(pages(:home_page), source_type: 'pagefreezer')

    body_json = JSON.parse @response.body
    types = body_json['data'].collect {|v| v['source_type']}.uniq

    assert_equal ['pagefreezer'], types, 'Got versions with wrong source_type'
  end

  test 'can annotate versions' do
    version = versions(:page1_v2)

    sign_in users(:alice)
    post(
      api_v0_page_version_annotations_url(pages(:home_page), version),
      as: :json,
      params: { something: 'some value' }
    )

    assert_response(:success)

    body = JSON.parse @response.body
    annotation_id = body['data']['uuid']
    ids = version.change_from_previous.annotations.pluck(:uuid)
    assert_includes(ids, annotation_id, 'Annotation was not added to version')
    assert_equal(
      'some value',
      version.current_annotation['something'],
      'Annotation was not incorporated into "current_annotaiton"'
    )
  end

  test 'cannot annotate the first version of a page' do
    version = versions(:page1_v1)

    sign_in users(:alice)
    post(
      api_v0_page_version_annotations_url(pages(:home_page), version),
      as: :json,
      params: { something: 'some value' }
    )

    assert_response(:not_found)
  end
end
