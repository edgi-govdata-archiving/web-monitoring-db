require 'test_helper'

class Api::V0::ChangesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test 'can list changes' do
    page = pages(:home_page)
    sign_in users(:alice)
    get(api_v0_page_changes_path(page))

    assert_response :success
    assert_equal 'application/json', @response.media_type
    body = JSON.parse @response.body
    assert body.key?('links'), 'Response should have a "links" property'
    assert body.key?('data'), 'Response should have a "data" property'
    assert body.key?('meta'), 'Response should have a "meta" property'
    assert(body['data'].is_a?(Array), 'Data should be an array')

    foreign_change_id = changes(:page2_change_1_2).uuid
    assert_not(
      body['data'].any? {|change| change['uuid'] == foreign_change_id},
      'Response included a change from a different page'
    )
  end

  test 'can get a single change by version IDs' do
    page = pages(:home_page)
    sign_in users(:alice)
    from_version = versions(:page1_v1)
    to_version = versions(:page1_v2)
    get(api_v0_page_change_path(page, "#{from_version.id}..#{to_version.id}"))

    assert_response :success
    assert_equal 'application/json', @response.media_type
    body = JSON.parse @response.body
    assert body.key?('links'), 'Response should have a "links" property'
    assert body.key?('data'), 'Response should have a "data" property'
    assert_equal(from_version.id, body['data']['uuid_from'], 'Response has wrong "from" version')
    assert_equal(to_version.id, body['data']['uuid_to'], 'Response has wrong "to" version')
  end

  test 'can filter by priority' do
    page = pages(:home_page)
    sign_in users(:alice)

    get(api_v0_page_changes_path(page, priority: '(0.5,)'))
    assert_response :success
    body = JSON.parse @response.body
    assert(body['data'].length.positive?, 'Did not get any changes back')
    body['data'].each do |change|
      priority = change['priority']
      assert(priority > 0.5, "Got a priority not > 0.5: #{priority} (from #{change['uuid']})")
    end

    get(api_v0_page_changes_path(page, priority: '[0.75,]'))
    assert_response :success
    body = JSON.parse @response.body
    assert(body['data'].length.positive?, 'Did not get any changes back')
    body['data'].each do |change|
      priority = change['priority']
      assert(priority >= 0.75, "Got a priority not >= 0.75: #{priority} (from #{change['uuid']})")
    end

    get(api_v0_page_changes_path(page, priority: '(,0.75)'))
    assert_response :success
    body = JSON.parse @response.body
    assert(body['data'].length.positive?, 'Did not get any changes back')
    body['data'].each do |change|
      priority = change['priority']
      assert(priority < 0.75, "Got a priority not < 0.5: #{priority} (from #{change['uuid']})")
    end

    get(api_v0_page_changes_path(page, priority: '[,0.5]'))
    assert_response :success
    body = JSON.parse @response.body
    assert(body['data'].length.positive?, 'Did not get any changes back')
    body['data'].each do |change|
      priority = change['priority']
      assert(priority <= 0.5, "Got a priority not <= 0.5: #{priority} (from #{change['uuid']})")
    end
  end

  test 'can filter by significance' do
    page = pages(:home_page)
    sign_in users(:alice)

    get(api_v0_page_changes_path(page, significance: '(0.5,)'))
    assert_response :success
    body = JSON.parse @response.body
    assert(body['data'].length.positive?, 'Did not get any changes back')
    body['data'].each do |change|
      significance = change['significance']
      assert(significance > 0.5, "Got a significance not > 0.5: #{significance} (from #{change['uuid']})")
    end

    get(api_v0_page_changes_path(page, significance: '[0.75,]'))
    assert_response :success
    body = JSON.parse @response.body
    assert(body['data'].length.positive?, 'Did not get any changes back')
    body['data'].each do |change|
      significance = change['significance']
      assert(significance >= 0.75, "Got a significance not >= 0.75: #{significance} (from #{change['uuid']})")
    end

    get(api_v0_page_changes_path(page, significance: '(,0.75)'))
    assert_response :success
    body = JSON.parse @response.body
    assert(body['data'].length.positive?, 'Did not get any changes back')
    body['data'].each do |change|
      significance = change['significance']
      assert(significance < 0.75, "Got a significance not < 0.5: #{significance} (from #{change['uuid']})")
    end

    get(api_v0_page_changes_path(page, significance: '[,0.5]'))
    assert_response :success
    body = JSON.parse @response.body
    assert(body['data'].length.positive?, 'Did not get any changes back')
    body['data'].each do |change|
      significance = change['significance']
      assert(significance <= 0.5, "Got a significance not <= 0.5: #{significance} (from #{change['uuid']})")
    end
  end

  test 'meta.total_results should be the total results across all chunks' do
    sign_in users(:alice)
    page = pages(:home_page)
    get(api_v0_page_changes_path(page, params: { include_total: true }))

    assert_response :success
    assert_equal 'application/json', @response.media_type
    body = JSON.parse @response.body
    assert_equal(
      page.tracked_changes.count,
      body['meta']['total_results'],
      'Should contain count of total results across all chunks'
    )
  end

  test 'can order changes with `?sort=field:direction`' do
    sign_in users(:alice)
    page = pages(:home_page)
    get(
      api_v0_page_changes_url(
        page,
        params: { sort: 'priority:asc,significance:asc' }
      )
    )
    assert_response(:success)
    body = JSON.parse(@response.body)
    assert_ordered_by(
      body['data'],
      [['priority'], ['significance']],
      name: 'Changes'
    )

    get(
      api_v0_page_changes_url(
        page,
        params: { sort: 'priority:desc,significance:desc' }
      )
    )
    assert_response(:success)
    body = JSON.parse(@response.body)
    assert_ordered_by(
      body['data'],
      [['priority', 'desc'], ['significance', 'desc']],
      name: 'Changes'
    )
  end
end
