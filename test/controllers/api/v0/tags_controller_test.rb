require 'test_helper'

class Api::V0::TagsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test 'cannot list tags without auth' do
    get api_v0_tags_path
    assert_response :unauthorized
  end

  test 'can list tags' do
    sign_in users(:alice)
    get api_v0_tags_path
    assert_response :success
    assert_equal 'application/json', @response.content_type
    body = JSON.parse @response.body

    assert body.key?('links'), 'Response should have a "links" property'
    assert body.key?('data'), 'Response should have a "data" property'
    assert body.key?('meta'), 'Response should have a "meta" property'
    assert_kind_of(Array, body['data'])

    body['data'].each do |tag|
      assert_includes(tag, 'uuid')
      assert_includes(tag, 'name')
    end
  end

  test 'can get a single tag' do
    sign_in users(:alice)
    get api_v0_tag_path(tags(:frequently_updated))
    assert_response :success
    assert_equal 'application/json', @response.content_type
    body = JSON.parse @response.body

    assert body.key?('data'), 'Response should have a "data" property'
    assert_kind_of(Hash, body['data'])
    assert_includes(body['data'], 'uuid')
    assert_includes(body['data'], 'name')
  end

  test "can list a page's tags" do
    pages(:home_page).add_tag(tags(:frequently_updated))

    sign_in users(:alice)
    get api_v0_page_tags_path(pages(:home_page))
    assert_response :success
    body = JSON.parse @response.body

    ids = body['data'].pluck('uuid')
    assert_includes(ids, tags(:frequently_updated).uuid)

    body['data'].each do |tag|
      assert_includes(tag, 'uuid')
      assert_includes(tag, 'name')
      assert_includes(tag, 'assigned_at')
    end
  end
end
