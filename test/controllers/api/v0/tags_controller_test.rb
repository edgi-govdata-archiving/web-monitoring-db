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
    assert_equal 'application/json', @response.media_type
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
    assert_equal 'application/json', @response.media_type
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

  test 'can add a tag to a page' do
    sign_in users(:alice)
    post(
      api_v0_page_tags_path(pages(:home_page)),
      as: :json,
      params: { name: 'Page of wonderment' }
    )
    assert_response(:success)
    body = JSON.parse(@response.body)
    assert_equal('Page of wonderment', body['data']['name'])

    get(api_v0_page_tags_path(pages(:home_page)))
    assert_response(:success)
    body = JSON.parse(@response.body)
    tag_names = body['data'].pluck('name')
    assert_includes(tag_names, 'Page of wonderment', 'The tag was not added to the page tags list')
  end

  test 'can add a tag to a page by UUID' do
    sign_in users(:alice)
    post(
      api_v0_page_tags_path(pages(:home_page)),
      as: :json,
      params: { uuid: tags(:site_whatever).uuid }
    )
    assert_response(:success)
    body = JSON.parse(@response.body)
    assert_equal('site:whatever', body['data']['name'])

    get(api_v0_page_tags_path(pages(:home_page)))
    assert_response(:success)
    body = JSON.parse(@response.body)
    tag_ids = body['data'].pluck('uuid')
    assert_includes(
      tag_ids,
      tags(:site_whatever).uuid,
      'The tag was not added to the page tags list'
    )
  end

  test 'can create a tag' do
    sign_in users(:alice)
    post(
      api_v0_tags_path,
      as: :json,
      params: { name: 'Page of wonderment' }
    )
    assert_response(:success)
    body = JSON.parse(@response.body)
    assert_equal('Page of wonderment', body['data']['name'])

    get(api_v0_tags_path)
    assert_response(:success)
    body = JSON.parse(@response.body)
    tag_names = body['data'].pluck('name')
    assert_includes(tag_names, 'Page of wonderment', 'The tag was not added to the tags list')
  end

  test 'cannot add a tag with no name or UUID to a page' do
    sign_in users(:alice)
    post(
      api_v0_page_tags_path(pages(:home_page)),
      as: :json,
      params: { xyz: 'Page of wonderment' }
    )
    assert_response(:bad_request)
  end

  test 'can edit a tag' do
    sign_in users(:alice)
    patch(
      api_v0_tag_path(tags(:site_whatever)),
      as: :json,
      params: { name: 'site:wherever' }
    )
    assert_response(:success)
    body = JSON.parse(@response.body)
    assert_equal('site:wherever', body['data']['name'])
  end

  test 'can delete a tag from a page' do
    pages(:home_page).add_tag(tags(:site_whatever))

    sign_in users(:alice)
    delete(api_v0_page_tag_path(pages(:home_page), tags(:site_whatever)))
    assert_response(:redirect)
    follow_redirect!
    assert_response(:success)
    body = JSON.parse(@response.body)

    assert_kind_of(Array, body['data'], 'A list of tags was not returned')
    tag_names = body['data'].pluck('name')
    assert_not_includes(tag_names, 'site:whatever', 'The tag was not removed from the page')
  end

  test 'can order tags with `?sort=field:direction`' do
    sign_in users(:alice)
    get(api_v0_tags_url(params: { sort: 'name:asc' }))
    assert_response(:success)
    body = JSON.parse(@response.body)
    assert_ordered_by(
      body['data'],
      [['name']],
      name: 'Tags'
    )

    get(api_v0_tags_url(params: { sort: 'name:desc' }))
    assert_response(:success)
    body = JSON.parse(@response.body)
    assert_ordered_by(
      body['data'],
      [['name', 'desc']],
      name: 'Tags'
    )
  end
end
