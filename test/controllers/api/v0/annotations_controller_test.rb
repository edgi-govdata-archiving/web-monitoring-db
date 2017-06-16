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

  test 'posting a new annotation updates previous annotations by the same user' do
    page = pages(:home_page)
    annotation1 = { 'test_key' => 'test_value' }
    annotation2 = { 'test_key' => 'new_value' }

    sign_in users(:alice)
    post(
      api_v0_page_version_annotations_path(page, page.versions[0]),
      as: :json,
      params: annotation1
    )
    sign_in users(:alice)
    post(
      api_v0_page_version_annotations_path(page, page.versions[0]),
      as: :json,
      params: annotation2
    )
    get(api_v0_page_version_annotations_path(page, page.versions[0]))

    assert_response :success
    body = JSON.parse @response.body
    assert_equal 1, body['data'].length, 'Multiple annotations were created'
    assert_equal annotation2, body['data'][0]['annotation']
  end

  test 'multiple users can annotate a change' do
    page = pages(:home_page)
    annotation1 = { 'test_key' => 'test_value' }
    annotation2 = { 'test_key' => 'new_value' }

    sign_in users(:alice)
    post(
      api_v0_page_version_annotations_path(page, page.versions[0]),
      as: :json,
      params: annotation1
    )

    sign_in users(:admin_user)
    post(
      api_v0_page_version_annotations_path(page, page.versions[0]),
      as: :json,
      params: annotation2
    )

    get(api_v0_page_version_annotations_path(page, page.versions[0]))

    assert_response :success
    body = JSON.parse @response.body
    assert_equal 2, body['data'].length, 'Two annotations were not created'
  end
end
