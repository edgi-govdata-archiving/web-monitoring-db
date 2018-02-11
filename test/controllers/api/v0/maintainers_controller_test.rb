require 'test_helper'

class Api::V0::MaintainersControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test 'cannot list maintainers without auth' do
    get api_v0_maintainers_path
    assert_response :unauthorized
  end

  test 'can list maintainers' do
    sign_in users(:alice)
    get api_v0_maintainers_path
    assert_response :success
    assert_equal 'application/json', @response.content_type
    body = JSON.parse @response.body

    assert body.key?('links'), 'Response should have a "links" property'
    assert body.key?('data'), 'Response should have a "data" property'
    assert body.key?('meta'), 'Response should have a "meta" property'
    assert_kind_of(Array, body['data'])

    body['data'].each do |maintainer|
      assert_includes(maintainer, 'uuid')
      assert_includes(maintainer, 'name')
      assert_includes(maintainer, 'parent_uuid')
    end
  end

  test 'can get a single maintainer' do
    sign_in users(:alice)
    get api_v0_maintainer_path(maintainers(:someone))
    assert_response :success
    assert_equal 'application/json', @response.content_type
    body = JSON.parse @response.body

    assert body.key?('links'), 'Response should have a "links" property'
    assert_includes(body['links'], 'parent', 'Maintainer should have a link to its parent')
    assert_includes(body['links'], 'children', 'Maintainer should have a link to its children')
    assert body.key?('data'), 'Response should have a "data" property'
    assert_kind_of(Hash, body['data'])
    assert_includes(body['data'], 'uuid')
    assert_includes(body['data'], 'name')
    assert_includes(body['data'], 'parent_uuid')
  end

  test "can list a page's maintainers" do
    pages(:home_page).add_maintainer(maintainers(:someone))

    sign_in users(:alice)
    get api_v0_page_maintainers_path(pages(:home_page))
    assert_response :success
    body = JSON.parse @response.body

    ids = body['data'].pluck('uuid')
    assert_includes(ids, maintainers(:someone).uuid)

    body['data'].each do |maintainer|
      assert_includes(maintainer, 'uuid')
      assert_includes(maintainer, 'name')
      assert_includes(maintainer, 'parent_uuid')
      assert_includes(maintainer, 'assigned_at')
    end
  end

  test 'can list maintainers by their parent' do
    maintainers(:someone).update(parent: maintainers(:epa))

    sign_in(users(:alice))
    get(api_v0_maintainers_path(params: { parent: maintainers(:epa).uuid }))
    assert_response(:success)
    body = JSON.parse(@response.body)

    assert_equal(1, body['data'].length)
    assert_equal(maintainers(:someone).uuid, body['data'][0]['uuid'])
  end

  test "can list a page's maintainers by their parent" do
    maintainers(:someone).update(parent: maintainers(:epa))
    pages(:home_page).add_maintainer(maintainers(:someone))
    pages(:home_page).add_maintainer(maintainers(:doi))

    sign_in(users(:alice))
    get(
      api_v0_page_maintainers_path(
        pages(:home_page),
        params: { parent: maintainers(:epa).uuid }
      )
    )
    assert_response(:success)
    body = JSON.parse(@response.body)

    assert_equal(1, body['data'].length)
    assert_equal(maintainers(:someone).uuid, body['data'][0]['uuid'])
  end
end
