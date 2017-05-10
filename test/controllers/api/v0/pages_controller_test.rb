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
end
