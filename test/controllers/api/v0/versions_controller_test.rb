require 'test_helper'

class Api::V0::VersionsControllerTest < ActionDispatch::IntegrationTest
  test 'can list versions' do
    get(api_v0_page_versions_url(pages(:home_page)))
    assert_response(:success)
    assert_equal('application/json', @response.content_type)
    body_json = JSON.parse(@response.body)
    assert(body_json.key?('links'), 'Response should have a "links" property')
    assert(body_json.key?('data'), 'Response should have a "data" property')
    assert(body_json['data'].is_a?(Array), 'Data shoudl be an array')
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
end
