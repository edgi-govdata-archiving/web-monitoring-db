require 'test_helper'

class Api::V0::ImportsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ActiveJob::TestHelper

  # These tests get network privileges (for now)
  def setup
    WebMock.allow_net_connect!
    @original_allowed_hosts = Archiver.allowed_hosts
    Archiver.allowed_hosts = ['https://test-bucket.s3.amazonaws.com']
  end

  def teardown
    WebMock.disable_net_connect!
    Archiver.allowed_hosts = @original_allowed_hosts
  end

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

  test 'does not add or modify a version if it already exists' do
    page_versions_count = pages(:home_page).versions.count
    original_data = versions(:page1_v1).as_json
    import_data = [
      {
        page_url: pages(:home_page).url,
        page_title: pages(:home_page).title,
        site_agency: 'The Federal Example Agency',
        site_name: pages(:home_page).site,
        capture_time: versions(:page1_v1).capture_time,
        uri: 'https://test-bucket.s3.amazonaws.com/example-v1',
        version_hash: 'INVALID_HASH',
        source_type: versions(:page1_v1).source_type,
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


    page = Page.find(pages(:home_page).uuid)
    version = Version.find(versions(:page1_v1).uuid)
    assert_equal(page_versions_count, page.versions.count)
    assert_equal(original_data['version_hash'], version.version_hash, 'version_hash was changed')
    assert_equal(original_data['source_metadata'], version.source_metadata, 'source_metadata was changed')
  end

  test 'replaces an existing version if requested' do
    page_versions_count = pages(:home_page).versions.count
    import_data = [
      {
        page_url: pages(:home_page).url,
        page_title: pages(:home_page).title,
        site_agency: 'The Federal Example Agency',
        site_name: pages(:home_page).site,
        capture_time: versions(:page1_v1).capture_time,
        uri: 'https://test-bucket.s3.amazonaws.com/example-v1',
        version_hash: 'INVALID_HASH',
        source_type: versions(:page1_v1).source_type,
        source_metadata: { test_meta: 'data' }
      }
    ]

    sign_in users(:alice)
    perform_enqueued_jobs do
      post(
        api_v0_imports_path(params: { update: 'replace' }),
        headers: { 'Content-Type': 'application/x-json-stream' },
        params: import_data.map(&:to_json).join("\n")
      )
    end

    page = Page.find(pages(:home_page).uuid)
    version = Version.find(versions(:page1_v1).uuid)
    assert_equal(page_versions_count, page.versions.count)
    assert_equal('INVALID_HASH', version.version_hash, 'version_hash was not changed')
    assert_equal({ 'test_meta' => 'data' }, version.source_metadata, 'source_metadata was not replaced')
  end

  test 'merges an existing version if requested' do
    page_versions_count = pages(:home_page).versions.count
    original_data = versions(:page1_v1).as_json
    import_data = [
      {
        page_url: pages(:home_page).url,
        page_title: pages(:home_page).title,
        site_agency: 'The Federal Example Agency',
        site_name: pages(:home_page).site,
        capture_time: versions(:page1_v1).capture_time,
        uri: 'https://test-bucket.s3.amazonaws.com/example-v1',
        version_hash: 'INVALID_HASH',
        source_type: versions(:page1_v1).source_type,
        source_metadata: { test_meta: 'data' }
      }
    ]

    sign_in users(:alice)
    perform_enqueued_jobs do
      post(
        api_v0_imports_path(params: { update: 'merge' }),
        headers: { 'Content-Type': 'application/x-json-stream' },
        params: import_data.map(&:to_json).join("\n")
      )
    end

    page = Page.find(pages(:home_page).uuid)
    version = Version.find(versions(:page1_v1).uuid)
    assert_equal(page_versions_count, page.versions.count)
    assert_equal('INVALID_HASH', version.version_hash, 'version_hash was not changed')
    expected_meta = original_data['source_metadata'].merge('test_meta' => 'data')
    assert_equal(expected_meta, version.source_metadata, 'source_metadata was not merged')
  end
end
