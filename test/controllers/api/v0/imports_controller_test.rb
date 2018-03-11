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
        title: 'Example Page',
        page_maintainers: ['The Federal Example Agency'],
        page_tags: ['Example Site'],
        capture_time: '2017-05-01T12:33:01Z',
        uri: 'https://test-bucket.s3.amazonaws.com/example-v1',
        version_hash: 'f366e89639758cd7f75d21e5026c04fb1022853844ff471865004b3274059686',
        source_type: 'some_source',
        source_metadata: { test_meta: 'data' }
      },
      {
        page_url: 'http://testsite.com/',
        title: 'Example Page',
        page_maintainers: ['The Federal Example Agency'],
        page_tags: ['Test', 'Home Page'],
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
    assert_equal(1, pages.length)
    assert_equal('com,testsite)/', pages[0].url_key, 'URL key was not generated')
    assert_equal(import_data[0][:title], pages[0].title)

    maintainer_names = pages[0].maintainers.pluck(:name).to_a
    imported_maintainers = import_data.flat_map {|d| d[:page_maintainers]}
    imported_maintainers.each do |name|
      assert_includes(maintainer_names, name)
    end

    tag_names = pages[0].tags.pluck(:name).collect(&:downcase)
    imported_tags = import_data.flat_map {|d| d[:page_tags]}
    imported_tags.each do |name|
      assert_includes(tag_names, name.downcase)
    end

    versions = pages[0].versions
    assert_equal(2, versions.length)
    assert_equal(import_data[0][:page_url], versions[1].capture_url)
    assert_equal(import_data[1][:page_url], versions[0].capture_url)
  end

  test 'can import data with deprecated `site_agency`, `site_name` fields' do
    import_data = [
      {
        page_url: 'http://testsite.com/',
        title: 'Example Page',
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
        title: 'Example Page',
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
    assert_equal import_data[0][:title], pages[0].title

    maintainer_names = pages[0].maintainers.pluck(:name)
    tag_names = pages[0].tags.pluck(:name).collect(&:downcase)
    assert_includes(maintainer_names, 'The Federal Example Agency')
    assert_includes(tag_names, 'site:example site')

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

  test 'surfaces page validation errors' do
    import_data = [
      {
        page_url: 'testsite',
        title: 'Example Page',
        site_agency: 'The Federal Example Agency',
        site_name: 'Example Site',
        capture_time: '2017-05-01T12:33:01Z',
        uri: 'https://test-bucket.s3.amazonaws.com/example-v1',
        version_hash: 'f366e89639758cd7f75d21e5026c04fb1022853844ff471865004b3274059686',
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
    assert_equal('pending', body_json['data']['status'])

    get api_v0_import_path(id: job_id)
    body_json = JSON.parse(@response.body)
    assert_equal('complete', body_json['data']['status'])
    assert_equal(1, body_json['data']['processing_errors'].length)
    assert_match(
      /\sURL\s/i,
      body_json['data']['processing_errors'].first,
      'The error message did not mention that the URL was invalid'
    )
  end

  test 'can import `null` page_maintainers' do
    import_data = [
      {
        page_url: 'http://testsite.com/',
        page_title: 'Test Page',
        page_maintainers: nil,
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

    assert_response :success
    body_json = JSON.parse(@response.body)
    job_id = body_json['data']['id']
    assert_equal 'pending', body_json['data']['status']

    get api_v0_import_path(id: job_id)
    body_json = JSON.parse(@response.body)
    assert_equal 'complete', body_json['data']['status']
    assert_equal 0, body_json['data']['processing_errors'].length
  end

  test 'cannot import non-array page_maintainers' do
    import_data = [
      {
        page_url: 'http://testsite.com/',
        page_title: 'Test Page',
        page_maintainers: 5,
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

    assert_response :success
    body_json = JSON.parse(@response.body)
    job_id = body_json['data']['id']
    assert_equal 'pending', body_json['data']['status']

    get api_v0_import_path(id: job_id)
    body_json = JSON.parse(@response.body)
    assert_equal 'complete', body_json['data']['status']
    assert_equal 1, body_json['data']['processing_errors'].length
  end

  test 'matches pages by url_key if no exact url match' do
    import_data = [
      {
        page_url: 'http://testSITE.com/whatever',
        title: 'Example Page',
        page_maintainers: ['The Federal Example Agency'],
        page_tags: ['Example Site'],
        capture_time: '2017-05-01T12:33:01Z',
        uri: 'https://test-bucket.s3.amazonaws.com/example-v1',
        version_hash: 'f366e89639758cd7f75d21e5026c04fb1022853844ff471865004b3274059686',
        source_type: 'some_source',
        source_metadata: { test_meta: 'data' }
      },
      {
        page_url: 'http://testsite.com/whatever/',
        title: 'Example Page',
        page_maintainers: ['The Federal Example Agency'],
        page_tags: ['Test', 'Home Page'],
        capture_time: '2017-05-03T12:33:01Z',
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

    imported_page = Page.find_by(url: 'http://testSITE.com/whatever')
    assert_equal(2, imported_page.versions.count, 'The imported versions were added to separate pages')
  end

  test 'can import `null` page_tags' do
    import_data = [
      {
        page_url: 'http://testsite.com/',
        page_title: 'Test Page',
        page_tags: nil,
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

    assert_response :success
    body_json = JSON.parse(@response.body)
    job_id = body_json['data']['id']
    assert_equal 'pending', body_json['data']['status']

    get api_v0_import_path(id: job_id)
    body_json = JSON.parse(@response.body)
    assert_equal 'complete', body_json['data']['status']
    assert_equal 0, body_json['data']['processing_errors'].length
  end

  test 'cannot import non-array page_tags' do
    import_data = [
      {
        page_url: 'http://testsite.com/',
        page_title: 'Test Page',
        page_tags: 5,
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

    assert_response :success
    body_json = JSON.parse(@response.body)
    job_id = body_json['data']['id']
    assert_equal 'pending', body_json['data']['status']

    get api_v0_import_path(id: job_id)
    body_json = JSON.parse(@response.body)
    assert_equal 'complete', body_json['data']['status']
    assert_equal 1, body_json['data']['processing_errors'].length
  end
end
