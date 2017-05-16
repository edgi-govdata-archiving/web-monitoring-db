require 'test_helper'

class Api::V0::AnnotationsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test 'can annotate a version' do
    page = pages(:home_page)
    annotation = { 'test_key' => 'test_value' }

    sign_in users(:alice)
    post(
      api_v0_page_version_annotations_path(page, page.versions[0]),
      as: :json,
      params: annotation
    )

    assert_response :success
    assert_equal 'application/json', @response.content_type
    body = JSON.parse @response.body
    assert body.key?('links'), 'Response should have a "links" property'
    assert body.key?('data'), 'Response should have a "data" property'
    assert_equal annotation, body['data']['annotation']
  end
end
