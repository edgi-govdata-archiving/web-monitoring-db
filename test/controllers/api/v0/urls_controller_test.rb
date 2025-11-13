# frozen_string_literal: true

require 'test_helper'

class Api::V0::UrlsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test 'can only list urls without auth if configured' do
    with_rails_configuration(:allow_public_view, true) do
      get api_v0_page_urls_path(pages(:home_page))
      assert_response :success
    end

    with_rails_configuration(:allow_public_view, false) do
      get api_v0_page_urls_path(pages(:home_page))
      assert_response :unauthorized
    end
  end

  test 'can list urls' do
    sign_in users(:alice)
    get api_v0_page_urls_path(pages(:home_page))
    assert_response :success
    assert_equal 'application/json', @response.media_type
    body = JSON.parse @response.body

    assert body.key?('links'), 'Response should have a "links" property'
    assert body.key?('data'), 'Response should have a "data" property'
    assert_kind_of(Array, body['data'])

    page_urls = pages(:home_page).urls.pluck(:url)
    body['data'].each do |page_url|
      assert_includes(page_url, 'uuid')
      assert_includes(page_url, 'url')
      assert_includes(page_urls, page_url['url'])
    end
  end

  test 'creating a url requires import permissions' do
    user = users(:alice)
    user.update permissions: (user.permissions - [User::IMPORT_PERMISSION])
    sign_in user

    post(
      api_v0_page_urls_path(pages(:home_page)),
      as: :json,
      params: { page_url: { url: 'https://example.gov/new_url' } }
    )
    assert_response(:forbidden)
  end

  test 'cannot create new urls in read-only mode' do
    with_rails_configuration(:read_only, true) do
      sign_in users(:alice)
      post(
        api_v0_page_urls_path(pages(:home_page)),
        as: :json,
        params: { page_url: { url: 'https://example.gov/new_url' } }
      )
      assert_response :locked
    end
  end

  test 'can create new urls' do
    sign_in users(:alice)
    post(
      api_v0_page_urls_path(pages(:home_page)),
      as: :json,
      params: { page_url: { url: 'https://example.gov/new_url' } }
    )
    assert_response :success
    assert_equal 'application/json', @response.media_type
    body = JSON.parse @response.body
    assert_equal('https://example.gov/new_url', body.dig('data', 'url'))
  end

  test 'cannot specify url_key when creating' do
    sign_in users(:alice)
    post(
      api_v0_page_urls_path(pages(:home_page)),
      as: :json,
      params: {
        page_url: {
          url: 'https://example.gov/new_url',
          url_key: 'gov.example)/old_url'
        }
      }
    )
    assert_response :success
    assert_equal 'application/json', @response.media_type
    body = JSON.parse @response.body
    assert_not_equal('gov.example)/old_url', body.dig('data', 'url_key'))
  end

  test 'cannot create duplicate urls' do
    page_url = pages(:home_page).urls.first

    sign_in users(:alice)
    post(
      api_v0_page_urls_path(pages(:home_page)),
      as: :json,
      params: {
        page_url: {
          url: page_url.url,
          from_time: page_url.from_time,
          to_time: page_url.to_time
        }
      }
    )
    assert_response :conflict
    assert_equal 'application/json', @response.media_type
  end

  test 'updating a url requires import permissions' do
    user = users(:alice)
    user.update permissions: (user.permissions - [User::IMPORT_PERMISSION])
    sign_in user

    page_url = pages(:home_page).urls.first
    new_from_time = Time.now.utc - 1.day
    put(
      api_v0_page_url_path(pages(:home_page), page_url),
      as: :json,
      params: { page_url: { from_time: new_from_time } }
    )
    assert_response(:forbidden)
  end

  test 'can update urls' do
    page_url = pages(:home_page).urls.first
    new_from_time = Time.now.utc - 1.day

    sign_in users(:alice)
    put(
      api_v0_page_url_path(pages(:home_page), page_url),
      as: :json,
      params: { page_url: { from_time: new_from_time } }
    )
    assert_response :success
    assert_equal 'application/json', @response.media_type
    body = JSON.parse @response.body
    assert_equal(new_from_time.round, Time.parse(body.dig('data', 'from_time')).round)
  end

  test 'cannot update url.url' do
    page_url = pages(:home_page).urls.first

    sign_in users(:alice)
    put(
      api_v0_page_url_path(pages(:home_page), page_url),
      as: :json,
      params: { page_url: { url: 'https://example.gov/some_new_url' } }
    )
    assert_response :unprocessable_content
    assert_equal 'application/json', @response.media_type
  end

  test 'cannot update url.url_key' do
    page_url = pages(:home_page).urls.first

    sign_in users(:alice)
    put(
      api_v0_page_url_path(pages(:home_page), page_url),
      as: :json,
      params: { page_url: { url_key: 'gov.example)/old_url' } }
    )
    # It just gets ignored, so this is "successful".
    assert_response :success
    assert_equal 'application/json', @response.media_type
    body = JSON.parse @response.body
    assert_not_equal('gov.example)/old_url', body.dig('data', 'url_key'))
  end

  test 'updating with a malformed url.from_time returns an error' do
    page_url = pages(:home_page).urls.first

    sign_in users(:alice)
    put(
      api_v0_page_url_path(pages(:home_page), page_url),
      as: :json,
      params: { page_url: { from_time: 'This is not a time' } }
    )
    assert_response :unprocessable_content
    assert_equal 'application/json', @response.media_type
  end

  test 'deleting a url requires import permissions' do
    user = users(:alice)
    user.update permissions: (user.permissions - [User::IMPORT_PERMISSION])
    sign_in user

    page_url = pages(:home_page).urls.create(url: 'https://example.gov/whatever')
    delete(api_v0_page_url_path(pages(:home_page), page_url))
    assert_response(:forbidden)
  end

  test 'can delete urls' do
    page_url = pages(:home_page).urls.create(url: 'https://example.gov/whatever')

    sign_in users(:alice)
    delete(api_v0_page_url_path(pages(:home_page), page_url))
    assert_redirected_to(api_v0_page_urls_path(pages(:home_page)))

    remaining_urls = pages(:home_page).urls.pluck(:url)
    assert_not_includes(remaining_urls, page_url.url)
  end

  test 'cannot delete the canonical url for a page' do
    page_url = pages(:home_page).urls.first

    sign_in users(:alice)
    delete(api_v0_page_url_path(pages(:home_page), page_url))
    assert_response :unprocessable_content
    assert_equal 'application/json', @response.media_type
  end
end
