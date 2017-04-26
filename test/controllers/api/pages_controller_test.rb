require 'test_helper'

class Api::PagesControllerTest < ActionDispatch::IntegrationTest
  test 'can list pages' do
    get '/api/v0/pages/'
    assert_response :success
    assert_equal 'application/json', @response.content_type
    body_json = JSON.parse @response.body
    assert body_json.has_key?('links'), 'Response should havea  "links" property'
    assert body_json.has_key?('data'), 'Response should havea  "data" property'
  end
end
