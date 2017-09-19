require 'test_helper'
require 'minitest/mock'

class Api::V0::DiffControllerTest < ActionDispatch::IntegrationTest
  setup do
    @differ = Differ::SimpleDiff.new('http://example.com')
    Differ.register(:special, @differ)
  end

  test 'can diff two versions' do
    change = changes(:page1_change_1_2)

    @differ.stub(:diff, 'Diff!') do
      get "/api/v0/pages/#{change.version.page.uuid}/changes/#{change.from_version.uuid}..#{change.version.uuid}/diff/special"
    end

    assert_response :success
    assert_equal 'application/json', @response.content_type
    body = JSON.parse @response.body
    assert body.key?('data'), 'Response should have a "data" property'
    assert_equal 'Diff!', body['data']['content']
  end

  test 'returns 501 (not implemented) error for unknown diff types' do
    change = changes(:page1_change_1_2)
    get "/api/v0/pages/#{change.version.page.uuid}/changes/#{change.from_version.uuid}..#{change.version.uuid}/diff/who_knows"

    assert_response :not_implemented
  end

  test 'returns 400 error for versions with no content' do
    change = changes(:page1_change_2_3)
    get "/api/v0/pages/#{change.version.page.uuid}/changes/#{change.from_version.uuid}..#{change.version.uuid}/diff/special"
    assert_response :bad_request
  end

  test 'fills in `diff_service_version` when the diff has a `version` field' do
    change = changes(:page1_change_1_2)
    raw_diff = {
      'diff' => [[0, 'some'], [1, 'content']],
      'version' => '1.0'
    }

    @differ.stub(:diff, raw_diff) do
      get "/api/v0/pages/#{change.version.page.uuid}/changes/#{change.from_version.uuid}..#{change.version.uuid}/diff/special"
    end

    assert_response(:success)
    assert_equal('application/json', @response.content_type)
    body = JSON.parse(@response.body)
    assert(body.key?('data'), 'Response should have a "data" property')
    assert_equal('1.0', body['data']['diff_service_version'])
  end
end
