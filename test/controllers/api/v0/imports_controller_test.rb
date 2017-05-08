require 'test_helper'

class Api::V0::ImportsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ActiveJob::TestHelper

  test 'can import data' do
    import_data = [
      {
        page_url: 'http://testsite.com/',
        page_title: 'Example Page',
        site_agency: 'The Federal Example Agency',
        site_name: 'Example Site',
        capture_time: '2017-05-01T12:33:01Z',
        uri: 'https://test-bucket.s3.amazonaws.com/example-v1',
        version_hash: 'f366e89639758cd7f75d21e5026c04fb1022853844ff471865004b3274059686',
        source_type: 'some_source',
        source_metadata: { test_meta: 'data' }
      },
      {
        page_url: 'http://testsite.com/',
        page_title: 'Example Page',
        site_agency: 'The Federal Example Agency',
        site_name: 'Example Site',
        capture_time: '2017-05-02T12:33:01Z',
        uri: 'https://test-bucket.s3.amazonaws.com/example-v2',
        version_hash: 'f366e89639758cd7f75d21e5026c04fb1022853844ff471865004b3274059687',
        source_type: 'some_source',
        source_metadata: { test_meta: 'data' }
      }
    ]

    sign_in users(:alice)

    perform_enqueued_jobs do
      post(
        api_v0_imports_path,
        headers: { 'Content-Type': 'application/x-json-stream' },
        params: import_data.map(&:to_json).join("\n")
      )
    end

    assert_response :success
    body_json = JSON.parse(@response.body)
    job_id = body_json['data']['id']
    assert_equal 'pending', body_json['data']['status']

    get api_v0_import_path(id: job_id)
    body_json = JSON.parse(@response.body)
    assert_equal 'complete', body_json['data']['status']
    assert_equal 0, body_json['data']['processing_errors'].length

    pages = Page.where(url: 'http://testsite.com/')
    assert_equal 1, pages.length
    assert_equal import_data[0][:page_title], pages[0].title
    assert_equal import_data[0][:site_agency], pages[0].agency
    assert_equal import_data[0][:site_name], pages[0].site

    versions = pages[0].versions
    assert_equal 2, versions.length
  end
end
