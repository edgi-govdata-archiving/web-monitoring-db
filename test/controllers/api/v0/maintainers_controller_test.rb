require 'test_helper'

class Api::V0::MaintainersControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test 'can only list maintainers without auth if configured' do
    with_rails_configuration(:allow_public_view, true) do
      get api_v0_maintainers_path
      assert_response :success
    end

    with_rails_configuration(:allow_public_view, false) do
      get api_v0_maintainers_path
      assert_response :unauthorized
    end
  end

  test 'can list maintainers' do
    sign_in users(:alice)
    get api_v0_maintainers_path
    assert_response :success
    assert_equal 'application/json', @response.media_type
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
    assert_equal 'application/json', @response.media_type
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

  test 'adding a maintainer requires annotate permissions' do
    user = users(:alice)
    user.update permissions: (user.permissions - [User::ANNOTATE_PERMISSION])
    sign_in user

    post(
      api_v0_maintainers_path,
      as: :json,
      params: { name: 'EPA' }
    )
    assert_response(:forbidden)
  end

  test 'cannot add a maintainer in read-only mode' do
    with_rails_configuration(:read_only, true) do
      sign_in users(:alice)
      post(
        api_v0_maintainers_path,
        as: :json,
        params: { name: 'EPA' }
      )
      assert_response(:locked)
    end
  end

  test 'can add a maintainer to a page' do
    sign_in users(:alice)
    post(
      api_v0_page_maintainers_path(pages(:home_page)),
      as: :json,
      params: { name: 'EPA' }
    )
    assert_response(:success)
    body = JSON.parse(@response.body)
    assert_equal('EPA', body['data']['name'])

    get(api_v0_page_maintainers_path(pages(:home_page)))
    assert_response(:success)
    body = JSON.parse(@response.body)
    maintainer_names = body['data'].pluck('name')
    assert_includes(
      maintainer_names,
      'EPA',
      'The maintainer was not added to the page maintainers list'
    )
  end

  test 'can add a maintainer to a page by UUID' do
    sign_in users(:alice)
    post(
      api_v0_page_maintainers_path(pages(:home_page)),
      as: :json,
      params: { uuid: maintainers(:epa).uuid }
    )
    assert_response(:success)
    body = JSON.parse(@response.body)
    assert_equal('EPA', body['data']['name'])

    get(api_v0_page_maintainers_path(pages(:home_page)))
    assert_response(:success)
    body = JSON.parse(@response.body)
    maintainer_ids = body['data'].pluck('uuid')
    assert_includes(
      maintainer_ids,
      maintainers(:epa).uuid,
      'The maintainer was not added to the page maintainers list'
    )
  end

  test 'can create a maintainer' do
    sign_in users(:alice)
    post(
      api_v0_maintainers_path,
      as: :json,
      params: { name: 'NCEA', parent_uuid: maintainers(:epa).uuid }
    )
    assert_response(:success)
    body = JSON.parse(@response.body)
    assert_equal('NCEA', body['data']['name'])

    get(api_v0_maintainers_path)
    assert_response(:success)
    body = JSON.parse(@response.body)
    maintainer_names = body['data'].pluck('name')
    assert_includes(
      maintainer_names,
      'NCEA',
      'The maintainer was not added to the maintainers list'
    )
  end

  test 'cannot create a maintainer that already exists' do
    sign_in users(:alice)

    post(api_v0_maintainers_path, as: :json, params: { name: 'NCEA' })
    assert_response(:success)

    post(api_v0_maintainers_path, as: :json, params: { name: 'NCEA' })
    assert_response(:conflict)
  end

  test 'cannot add a maintainer to a page if it would mean creating a conflicting maintainer' do
    sign_in users(:alice)
    post(
      api_v0_page_maintainers_path(pages(:home_page)),
      as: :json,
      params: { name: 'EPA' }
    )
    assert_response(:success)

    # It's not an error to add a maintainer that is already there...
    post(
      api_v0_page_maintainers_path(pages(:home_page)),
      as: :json,
      params: { name: 'EPA' }
    )
    assert_response(:success)

    # ...but it is one to try and create a conlicting maintainer
    post(
      api_v0_page_maintainers_path(pages(:home_page)),
      as: :json,
      params: { name: 'EPA', parent_uuid: maintainers(:epa).uuid }
    )
    assert_response(:conflict)
  end

  test 'cannot add a maintainer with no name or UUID to a page' do
    sign_in users(:alice)
    post(
      api_v0_page_maintainers_path(pages(:home_page)),
      as: :json,
      params: { xyz: 'Magical Maintainer' }
    )
    assert_response(:bad_request)
  end

  test 'editing a maintainer requires annotate permissions' do
    user = users(:alice)
    user.update permissions: (user.permissions - [User::ANNOTATE_PERMISSION])
    sign_in user

    patch(
      api_v0_maintainer_path(maintainers(:epa)),
      as: :json,
      params: { name: 'epa' }
    )
    assert_response(:forbidden)
  end

  test 'can edit a maintainer' do
    sign_in users(:alice)
    patch(
      api_v0_maintainer_path(maintainers(:epa)),
      as: :json,
      params: { name: 'epa' }
    )
    assert_response(:success)
    body = JSON.parse(@response.body)
    assert_equal('epa', body['data']['name'])
  end

  test 'deleting a maintainer from a page requires annotate permissions' do
    user = users(:alice)
    user.update permissions: (user.permissions - [User::ANNOTATE_PERMISSION])
    sign_in user

    pages(:home_page).add_maintainer(maintainers(:epa))
    delete(api_v0_page_maintainer_path(pages(:home_page), maintainers(:epa)))
    assert_response(:forbidden)
  end

  test 'can delete a maintainer from a page' do
    pages(:home_page).add_maintainer(maintainers(:epa))

    sign_in users(:alice)
    delete(api_v0_page_maintainer_path(pages(:home_page), maintainers(:epa)))
    assert_response(:redirect)
    follow_redirect!
    assert_response(:success)
    body = JSON.parse(@response.body)

    assert_kind_of(Array, body['data'], 'A list of maintainers was not returned')
    maintainer_names = body['data'].pluck('name')
    assert_not_includes(maintainer_names, 'EPA', 'The maintainer was not removed from the page')
  end

  test 'can order maintainers with `?sort=field:direction`' do
    sign_in users(:alice)
    get(api_v0_maintainers_url(params: { sort: 'name:asc' }))
    assert_response(:success)
    body = JSON.parse(@response.body)
    assert_ordered_by(
      body['data'],
      [['name']],
      name: 'Maintainers'
    )

    get(api_v0_maintainers_url(params: { sort: 'name:desc' }))
    assert_response(:success)
    body = JSON.parse(@response.body)
    assert_ordered_by(
      body['data'],
      [['name', 'desc']],
      name: 'Maintainers'
    )
  end
end
