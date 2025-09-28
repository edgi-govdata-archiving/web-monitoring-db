require 'test_helper'

class Api::V0::ImportsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ActiveJob::TestHelper

  class MockDiffer
    def diff(_change, _options = nil)
      {
        'change_count' => 2,
        'diff' => [
          [0, 'abc'],
          [-1, 'def'],
          [1, 'ghi']
        ],
        'version' => '0.1.0',
        'type' => 'html_text_dmp'
      }
    end
  end

  # These tests get network privileges (for now)
  setup do
    WebMock.allow_net_connect!
    @original_allowed_hosts = Archiver.allowed_hosts
    Archiver.allowed_hosts = ['https://test-bucket.s3.amazonaws.com']
    # Imports trigger analysis, which uses these diffs
    Differ.register('html_source_dmp', MockDiffer.new)
    Differ.register('html_text_dmp', MockDiffer.new)
    Differ.register('links_json', MockDiffer.new)
  end

  teardown do
    WebMock.disable_net_connect!
    Archiver.allowed_hosts = @original_allowed_hosts
  end

  test 'authorizations' do
    import_data = [
      {
        url: 'http://testsite.com/',
        title: 'Example Page',
        page_maintainers: ['The Federal Example Agency'],
        page_tags: ['Example Site'],
        capture_time: '2017-05-01T12:33:01Z',
        body_url: 'https://test-bucket.s3.amazonaws.com/example-v1',
        body_hash: 'f366e89639758cd7f75d21e5026c04fb1022853844ff471865004b3274059686',
        source_type: 'some_source',
        source_metadata: { test_meta: 'data' }
      },
      {
        url: 'http://testsite.com/',
        title: 'Example Page',
        page_maintainers: ['The Federal Example Agency'],
        page_tags: ['Test', 'Home Page'],
        capture_time: '2017-05-02T12:33:01Z',
        body_url: 'https://test-bucket.s3.amazonaws.com/example-v2',
        body_hash: 'f366e89639758cd7f75d21e5026c04fb1022853844ff471865004b3274059687',
        source_type: 'some_source',
        source_metadata: { test_meta: 'data' }
      }
    ]

    post(
      api_v0_imports_path,
      headers: { 'Content-Type': 'application/x-json-stream' },
      params: import_data.map(&:to_json).join("\n")
    )
    assert_response(:unauthorized)

    user = users(:alice)
    user.update permissions: (user.permissions - [User::IMPORT_PERMISSION])
    sign_in user

    post(
      api_v0_imports_path,
      headers: { 'Content-Type': 'application/x-json-stream' },
      params: import_data.map(&:to_json).join("\n")
    )
    assert_response(:forbidden)
  end

  test 'can import data' do
    import_data = [
      {
        url: 'http://testsite.com/',
        title: 'Example Page',
        page_maintainers: ['The Federal Example Agency'],
        page_tags: ['Example Site'],
        capture_time: '2017-05-01T12:33:01Z',
        body_url: 'https://test-bucket.s3.amazonaws.com/example-v1',
        body_hash: 'f366e89639758cd7f75d21e5026c04fb1022853844ff471865004b3274059686',
        source_type: 'some_source',
        source_metadata: { test_meta: 'data' }
      },
      {
        url: 'http://testsite.com/',
        title: 'Example Page',
        page_maintainers: ['The Federal Example Agency'],
        page_tags: ['Test', 'Home Page'],
        capture_time: '2017-05-02T12:33:01Z',
        body_url: 'https://test-bucket.s3.amazonaws.com/example-v2',
        body_hash: 'f366e89639758cd7f75d21e5026c04fb1022853844ff471865004b3274059687',
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
    assert_equal(import_data[0][:url], versions[1].url)
    assert_equal(import_data[1][:url], versions[0].url)
  end

  test 'cannot import in read-only mode' do
    import_data = [
      {
        url: 'http://testsite.com/',
        title: 'Example Page',
        page_maintainers: ['The Federal Example Agency'],
        page_tags: ['Example Site'],
        capture_time: '2017-05-01T12:33:01Z',
        body_url: 'https://test-bucket.s3.amazonaws.com/example-v1',
        body_hash: 'f366e89639758cd7f75d21e5026c04fb1022853844ff471865004b3274059686',
        source_type: 'some_source',
        source_metadata: { test_meta: 'data' }
      },
      {
        url: 'http://testsite.com/',
        title: 'Example Page',
        page_maintainers: ['The Federal Example Agency'],
        page_tags: ['Test', 'Home Page'],
        capture_time: '2017-05-02T12:33:01Z',
        body_url: 'https://test-bucket.s3.amazonaws.com/example-v2',
        body_hash: 'f366e89639758cd7f75d21e5026c04fb1022853844ff471865004b3274059687',
        source_type: 'some_source',
        source_metadata: { test_meta: 'data' }
      }
    ]

    start_version_count = Version.count

    with_rails_configuration(:read_only, true) do
      sign_in users(:alice)
      perform_enqueued_jobs do
        post(
          api_v0_imports_path,
          headers: { 'Content-Type': 'application/x-json-stream' },
          params: import_data.map(&:to_json).join("\n")
        )
      end

      assert_response :locked
      assert_equal Version.count, start_version_count
    end
  end

  test 'does not add or modify a version if it already exists' do
    page_versions_count = pages(:home_page).versions.count
    original_data = versions(:page1_v1).as_json
    import_data = [
      {
        url: pages(:home_page).url,
        title: pages(:home_page).title,
        page_maintainers: ['The Federal Example Agency'],
        page_tags: pages(:home_page).tag_names,
        capture_time: versions(:page1_v1).capture_time,
        body_url: 'https://test-bucket.s3.amazonaws.com/example-v1',
        body_hash: 'INVALID_HASH',
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
    assert_equal(original_data['body_hash'], version.body_hash, 'body_hash was changed')
    assert_equal(original_data['source_metadata'], version.source_metadata, 'source_metadata was changed')
  end

  test 'replaces an existing version if requested' do
    page_versions_count = pages(:home_page).versions.count
    import_data = [
      {
        url: pages(:home_page).url,
        title: pages(:home_page).title,
        page_maintainers: ['The Federal Example Agency'],
        page_tags: pages(:home_page).tag_names,
        capture_time: versions(:page1_v1).capture_time,
        body_url: 'https://test-bucket.s3.amazonaws.com/example-v1',
        body_hash: 'INVALID_HASH',
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
    assert_equal('INVALID_HASH', version.body_hash, 'body_hash was not changed')
    assert_equal({ 'test_meta' => 'data' }, version.source_metadata, 'source_metadata was not replaced')
  end

  test 'merges an existing version if requested' do
    page_versions_count = pages(:home_page).versions.count
    original_data = versions(:page1_v1).as_json
    import_data = [
      {
        url: pages(:home_page).url,
        title: pages(:home_page).title,
        page_maintainers: ['The Federal Example Agency'],
        page_tags: pages(:home_page).tag_names,
        capture_time: versions(:page1_v1).capture_time,
        body_url: 'https://test-bucket.s3.amazonaws.com/example-v1',
        body_hash: 'INVALID_HASH',
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
    assert_equal('INVALID_HASH', version.body_hash, 'body_hash was not changed')
    expected_meta = original_data['source_metadata'].merge('test_meta' => 'data')
    assert_equal(expected_meta, version.source_metadata, 'source_metadata was not merged')
  end

  test 'surfaces page validation errors' do
    import_data = [
      {
        url: 'testsite',
        title: 'Example Page',
        page_maintainers: ['The Federal Example Agency'],
        page_tags: ['site:Example Site'],
        capture_time: '2017-05-01T12:33:01Z',
        body_url: 'https://test-bucket.s3.amazonaws.com/example-v1',
        body_hash: 'f366e89639758cd7f75d21e5026c04fb1022853844ff471865004b3274059686',
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

  test 'validates the body_hash' do
    stub_request(:any, 'http://example.storage/example-v1')
      .to_return(body: 'Hello!', status: 200)

    import_data = [
      {
        url: 'http://testsite.com/',
        title: 'Example Page',
        page_maintainers: ['The Federal Example Agency'],
        page_tags: ['site:Example Site'],
        capture_time: '2017-05-01T12:33:01Z',
        body_url: 'http://example.storage/example-v1',
        body_hash: 'f366e89639758cd7f75d21e5026c04fb1022853844ff471865004b3274059686',
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
      /\shash\s/i,
      body_json['data']['processing_errors'].first,
      'The error message did not mention an issue with the hash'
    )
  end

  test 'can import `null` page_maintainers' do
    import_data = [
      {
        url: 'http://testsite.com/',
        title: 'Test Page',
        page_maintainers: nil,
        capture_time: versions(:page1_v1).capture_time,
        body_url: 'https://test-bucket.s3.amazonaws.com/example-v1',
        body_hash: 'INVALID_HASH',
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
        url: 'http://testsite.com/',
        title: 'Test Page',
        page_maintainers: 5,
        capture_time: versions(:page1_v1).capture_time,
        body_url: 'https://test-bucket.s3.amazonaws.com/example-v1',
        body_hash: 'INVALID_HASH',
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
        url: 'http://testSITE.com/whatever',
        title: 'Example Page',
        page_maintainers: ['The Federal Example Agency'],
        page_tags: ['Example Site'],
        capture_time: '2017-05-01T12:33:01Z',
        body_url: 'https://test-bucket.s3.amazonaws.com/example-v1',
        body_hash: 'f366e89639758cd7f75d21e5026c04fb1022853844ff471865004b3274059686',
        source_type: 'some_source',
        source_metadata: { test_meta: 'data' }
      },
      {
        url: 'http://testsite.com/whatever/',
        title: 'Example Page',
        page_maintainers: ['The Federal Example Agency'],
        page_tags: ['Test', 'Home Page'],
        capture_time: '2017-05-03T12:33:01Z',
        body_url: 'https://test-bucket.s3.amazonaws.com/example-v2',
        body_hash: 'f366e89639758cd7f75d21e5026c04fb1022853844ff471865004b3274059687',
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
        url: 'http://testsite.com/',
        title: 'Test Page',
        page_tags: nil,
        capture_time: versions(:page1_v1).capture_time,
        body_url: 'https://test-bucket.s3.amazonaws.com/example-v1',
        body_hash: 'INVALID_HASH',
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
        url: 'http://testsite.com/',
        title: 'Test Page',
        page_tags: 5,
        capture_time: versions(:page1_v1).capture_time,
        body_url: 'https://test-bucket.s3.amazonaws.com/example-v1',
        body_hash: 'INVALID_HASH',
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

  test 'can not create new pages if ?create_pages=false' do
    existing_page_versions = pages(:home_page).versions.count

    import_data = [
      {
        url: 'http://whoa-there-betcha-this.com/is/not/in/the/database',
        title: 'Heyooooo!',
        capture_time: '2017-05-01T12:33:01Z',
        body_url: 'https://test-bucket.s3.amazonaws.com/unknown-v1',
        body_hash: 'abc',
        source_type: 'some_source',
        source_metadata: { test_meta: 'data' }
      },
      {
        url: pages(:home_page).url,
        title: 'Example Page',
        capture_time: '2017-05-02T12:33:01Z',
        body_url: 'https://test-bucket.s3.amazonaws.com/example-v2',
        body_hash: 'def',
        source_type: 'some_source',
        source_metadata: { test_meta: 'data' }
      }
    ]

    sign_in users(:alice)

    perform_enqueued_jobs do
      post(
        api_v0_imports_path(params: { create_pages: false }),
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
    assert_equal(0, body_json['data']['processing_errors'].length)
    assert_equal(1, body_json['data']['processing_warnings'].length)

    pages = Page.where(url: 'http://whoa-there-betcha-this.com/is/not/in/the/database')
    assert_equal(0, pages.count)
    assert_equal(existing_page_versions + 1, pages(:home_page).versions.count)
  end

  test 'can skip versions that are the same as the previous version if ?skip_unchanged_versions=true' do
    now = Time.now
    page = Page.create(url: 'http://thecoolest.com/for/reals')
    page.versions.create(capture_time: now - 5.days, body_hash: 'abc', source_type: 'a')
    page.versions.create(capture_time: now - 4.days, body_hash: 'def', source_type: 'b')

    # The first two here should get skipped
    import_data = [
      {
        url: page.url,
        title: 'Heyooooo!',
        capture_time: (now - 3.days).iso8601,
        body_url: 'https://test-bucket.s3.amazonaws.com/unknown-v1',
        body_hash: 'abc',
        source_type: 'a',
        source_metadata: { test_meta: 'data' }
      },
      {
        url: page.url,
        title: 'Heyooooo!',
        capture_time: (now - 2.9.days).iso8601,
        body_url: 'https://test-bucket.s3.amazonaws.com/unknown-v1',
        body_hash: 'def',
        source_type: 'b',
        source_metadata: { test_meta: 'data' }
      },
      {
        url: page.url,
        title: 'Heyooooo!',
        capture_time: (now - 2.5.days).iso8601,
        body_url: 'https://test-bucket.s3.amazonaws.com/unknown-v1',
        body_hash: 'def',
        source_type: 'a',
        source_metadata: { test_meta: 'data' }
      },
      {
        url: page.url,
        title: 'Heyooooo!',
        capture_time: (now - 2.days).iso8601,
        body_url: 'https://test-bucket.s3.amazonaws.com/unknown-v1',
        body_hash: 'xyz',
        source_type: 'b',
        source_metadata: { test_meta: 'data' }
      }
    ]

    sign_in users(:alice)

    perform_enqueued_jobs do
      post(
        api_v0_imports_path(params: { skip_unchanged_versions: true }),
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
    assert_equal(0, body_json['data']['processing_errors'].length, 'There were processing errors')
    assert_equal(2, body_json['data']['processing_warnings'].length, 'There were not warnings for each skipped version')
    assert_equal(4, page.versions.reload.count, 'There should have been 4 total versions after importing')
  end
end
