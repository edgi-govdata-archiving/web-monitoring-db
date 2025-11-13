# frozen_string_literal: true

require 'test_helper'
require 'minitest/mock'

class Api::V0::DiffControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @original_default_differ = Differ.for_type(nil)
  end

  teardown do
    Differ.register(nil, @original_default_differ)
  end

  test 'can diff two versions' do
    sign_in users(:alice)
    differ = Differ::SimpleDiff.new('http://example.com')
    Differ.register(:special, differ)

    change = changes(:page1_change_1_2)

    differ.stub(:diff, 'Diff!') do
      get "/api/v0/pages/#{change.version.page.uuid}/changes/#{change.from_version.uuid}..#{change.version.uuid}/diff/special"
    end

    assert_response :success
    assert_equal 'application/json', @response.media_type
    body = JSON.parse @response.body
    assert body.key?('data'), 'Response should have a "data" property'
    assert_equal 'Diff!', body['data']
  end

  test 'returns 501 (not implemented) error for unknown diff types when no default differ is configured' do
    Differ.register(nil, nil)

    sign_in users(:alice)
    change = changes(:page1_change_1_2)
    get "/api/v0/pages/#{change.version.page.uuid}/changes/#{change.from_version.uuid}..#{change.version.uuid}/diff/who_knows"

    assert_response :not_implemented
  end

  test 'returns 400 error for versions with no content' do
    sign_in users(:alice)
    change = changes(:page1_change_2_3)
    get "/api/v0/pages/#{change.version.page.uuid}/changes/#{change.from_version.uuid}..#{change.version.uuid}/diff/special"
    assert_response :bad_request
  end
end
