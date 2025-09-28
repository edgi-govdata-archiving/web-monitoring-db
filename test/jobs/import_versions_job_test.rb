require 'test_helper'

class ImportVersionsJobTest < ActiveJob::TestCase
  make_my_diffs_pretty!

  class FakeLogger
    def logs
      @logs ||= []
    end

    def debug(message)
      logs.push(message)
    end

    def info(message)
      logs.push(message)
    end

    def warn(message)
      logs.push(message)
    end

    def error(message)
      logs.push(message)
    end
  end

  setup do
    @original_allowed_hosts = Archiver.allowed_hosts
    Archiver.allowed_hosts = ['https://test-bucket.s3.amazonaws.com']

    @original_logger = Rails.logger
    Rails.logger = FakeLogger.new
  end

  teardown do
    Archiver.allowed_hosts = @original_allowed_hosts
    Rails.logger = @original_logger

    # Clear any stored files.
    if Archiver.store.is_a?(FileStorage::LocalFile)
      FileUtils.remove_dir(Archiver.store.directory, true)
    end
  end

  def assert_field(raw, version, name, expected: nil)
    expected = raw[name] if expected.nil?
    assert_equal(expected, version.send(name), "#{name} was not set")
  end

  test 'imports a version' do
    raw_data = {
      url: pages(:home_page).url,
      capture_time: '2025-01-01T00:00:00Z',
      body_url: 'https://test-bucket.s3.amazonaws.com/some-archived-copy.html',
      body_hash: 'INVALID_HASH',
      source_type: 'test-source',
      source_metadata: { test_meta: 'data' },
      status: 200,
      headers: { 'Some-Header' => 'value' },
      title: pages(:home_page).title,
      content_length: nil,
      media_type: nil,
      page_maintainers: ['The Federal Example Agency'],
      page_tags: ['Some tag']
    }

    import = Import.create_with_data(
      { user: users(:alice) },
      [raw_data].map(&:to_json).join("\n")
    )

    ImportVersionsJob.perform_now(import)
    assert_equal([], import.processing_errors, 'There were processing errors')

    page = Page.find(pages(:home_page).uuid)
    version = Version.where(url: raw_data[:url], capture_time: raw_data[:capture_time]).first
    assert_not_nil(version)
    assert_equal(
      {
        **raw_data.with_indifferent_access.except(:page_maintainers, :page_tags),
        'page_uuid' => page.uuid,
        'capture_time' => Time.parse(raw_data[:capture_time]),
        'headers' => raw_data[:headers].transform_keys(&:downcase),
        'network_error' => nil
      }.sort.to_h,
      {
        **version.attributes.except('uuid', 'created_at', 'updated_at', 'different'),
        'capture_time' => version.capture_time
      }.sort.to_h
    )

    page_tags = page.tags.map(&:name)
    raw_data[:page_tags].each { |name| assert_includes(page_tags, name) }
    page_maintainers = page.maintainers.map(&:name)
    raw_data[:page_maintainers].each { |name| assert_includes(page_maintainers, name) }
  end

  test 'imports an error version' do
    raw_data = {
      url: pages(:home_page).url,
      capture_time: '2025-01-01T00:00:00Z',
      network_error: 'net::ERR_NAME_NOT_RESOLVED',
      source_type: 'test-source',
      source_metadata: { test_meta: 'data' }
    }

    import = Import.create_with_data(
      { user: users(:alice) },
      [raw_data].map(&:to_json).join("\n")
    )

    ImportVersionsJob.perform_now(import)
    assert_equal([], import.processing_errors, 'There were processing errors')

    page = Page.find(pages(:home_page).uuid)
    version = Version.where(url: raw_data[:url], capture_time: raw_data[:capture_time]).first
    assert_not_nil(version)
    assert_equal(
      {
        **raw_data.with_indifferent_access.except(:page_maintainers, :page_tags),
        'page_uuid' => page.uuid,
        'capture_time' => Time.parse(raw_data[:capture_time]),
        'headers' => nil,
        'body_url' => nil,
        'body_hash' => nil,
        'content_length' => nil,
        'media_type' => nil,
        'status' => nil,
        'title' => nil
      }.sort.to_h,
      {
        **version.attributes.except('uuid', 'created_at', 'updated_at', 'different'),
        'capture_time' => version.capture_time
      }.sort.to_h
    )
  end

  test 'does not add or modify a version if it already exists' do
    page_versions_count = pages(:home_page).versions.count
    original_data = versions(:page1_v1).as_json

    import = Import.create_with_data(
      {
        user: users(:alice)
      },
      [
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
      ].map(&:to_json).join("\n")
    )
    ImportVersionsJob.perform_now(import)

    assert_equal(page_versions_count, pages(:home_page).versions.count)
    assert_equal(original_data['body_hash'], versions(:page1_v1).body_hash, 'body_hash was changed')
    assert_equal(original_data['source_metadata'], versions(:page1_v1).source_metadata, 'source_metadata was changed')
  end

  test 'replaces an existing version if requested' do
    page_versions_count = pages(:home_page).versions.count

    import = Import.create_with_data(
      {
        user: users(:alice),
        update_behavior: :replace
      },
      [
        {
          url: pages(:home_page).url,
          title: pages(:home_page).title,
          page_maintainers: ['The Federal Example Agency'],
          page_tags: pages(:home_page).tag_names,
          capture_time: versions(:page1_v5).capture_time,
          # NOTE: `body_url` is left out intentionally; it should get set to nil
          body_hash: 'INVALID_HASH',
          source_type: versions(:page1_v5).source_type,
          source_metadata: { test_meta: 'data' }
        }
      ].map(&:to_json).join("\n")
    )

    ImportVersionsJob.perform_now(import)

    page = Page.find(pages(:home_page).uuid)
    version = Version.find(versions(:page1_v5).uuid)
    assert_equal([], import.processing_errors, 'There were processing errors')
    assert_equal(page_versions_count, page.versions.count, 'A new version was added')
    assert_nil(version.body_url, 'body_url was not changed')
    assert_equal('INVALID_HASH', version.body_hash, 'body_hash was not changed')
    assert_equal({ 'test_meta' => 'data' }, version.source_metadata, 'source_metadata was not replaced')

    assert_equal([
                   "[import=#{import.id}] Started Import #{import.id}",
                   "[import=#{import.id}][row=0] Found Page #{page.uuid}",
                   "[import=#{import.id}][row=0] Replaced Version #{versions(:page1_v5).uuid}",
                   "[import=#{import.id}] Finished Import #{import.id}",
                   "Import #{import.id}: Auto-analysis is not configured; AnalyzeChangeJobs were not scheduled for imported versions."
                 ], Rails.logger.logs, 'Logs are not as expected.')
  end

  test 'merges with an existing version if requested' do
    page_versions_count = pages(:home_page).versions.count
    original_body_url = versions(:page1_v5).body_url
    original_meta = versions(:page1_v5).source_metadata

    import = Import.create_with_data(
      {
        user: users(:alice),
        update_behavior: :merge
      },
      [
        {
          url: pages(:home_page).url,
          title: pages(:home_page).title,
          page_maintainers: ['The Federal Example Agency'],
          page_tags: pages(:home_page).tag_names,
          capture_time: versions(:page1_v5).capture_time,
          # NOTE: body_url is intentionally left out; it should not get set to nil
          body_hash: 'INVALID_HASH',
          source_type: versions(:page1_v5).source_type,
          source_metadata: { test_meta: 'data' }
        }
      ].map(&:to_json).join("\n")
    )
    ImportVersionsJob.perform_now(import)

    page = Page.find(pages(:home_page).uuid)
    version = Version.find(versions(:page1_v5).uuid)
    assert_equal([], import.processing_errors, 'There were processing errors')
    assert_equal(page_versions_count, page.versions.count, 'A new version was added')
    assert_equal(original_body_url, version.body_url, 'body_url was changed')
    assert_equal('INVALID_HASH', version.body_hash, 'body_hash was not changed')
    expected_meta = original_meta.merge('test_meta' => 'data')
    assert_equal(expected_meta, version.source_metadata, 'source_metadata was not merged')
  end

  test 'raises helpful error if url is missing' do
    import = Import.create_with_data(
      {
        user: users(:alice),
        update_behavior: :merge
      },
      [
        {
          # omitted url
          title: pages(:home_page).title,
          page_maintainers: ['The Federal Example Agency'],
          page_tags: pages(:home_page).tag_names,
          capture_time: versions(:page1_v5).capture_time,
          # NOTE: body_url is intentionally left out; it should not get set to nil
          body_hash: 'INVALID_HASH',
          source_type: versions(:page1_v5).source_type,
          source_metadata: { test_meta: 'data' }
        }
      ].map(&:to_json).join("\n")
    )
    ImportVersionsJob.perform_now(import)
    assert_equal(['Row 0: `url` is missing'], import.processing_errors, 'expected error due to missing url')
  end

  test 'does not import versions for inactive pages' do
    page_versions_count = pages(:inactive_page).versions.count
    now = Time.now

    import = Import.create_with_data(
      {
        user: users(:alice)
      },
      [
        {
          url: pages(:inactive_page).url,
          title: pages(:inactive_page).title,
          capture_time: now,
          body_url: 'https://test-bucket.s3.amazonaws.com/inactive-v1',
          body_hash: 'abc',
          source_type: 'test_source',
          source_metadata: { test_meta: 'data' }
        }
      ].map(&:to_json).join("\n")
    )
    ImportVersionsJob.perform_now(import)

    assert_equal(page_versions_count, pages(:inactive_page).versions.count)
    assert_nil(pages(:inactive_page).versions.where(capture_time: now).first)
    assert_any_includes(import.processing_warnings, 'inactive')
  end

  test 'does not import versions if URL did not match body_hash' do
    page_versions_count = pages(:home_page).versions.count
    now = Time.now

    stub_request(:any, 'http://example.com')
      .to_return(body: 'Hello!', status: 200)

    import = Import.create_with_data(
      {
        user: users(:alice)
      },
      [
        {
          url: pages(:home_page).url,
          capture_time: now,
          body_url: 'http://example.com',
          body_hash: 'abc',
          source_type: 'test_source',
          source_metadata: { test_meta: 'data' }
        }
      ].map(&:to_json).join("\n")
    )
    ImportVersionsJob.perform_now(import)

    assert_equal(page_versions_count, pages(:home_page).versions.count)
    assert_nil(pages(:home_page).versions.where(capture_time: now).first)
    assert_any_includes(import.processing_errors, 'hash')
  end

  test 'allows "hash" instead of "body_hash"' do
    page_versions_count = pages(:home_page).versions.count
    now = Time.now

    stub_request(:any, 'http://example.com')
      .to_return(body: 'Hello!', status: 200)

    import = Import.create_with_data(
      {
        user: users(:alice)
      },
      [
        {
          url: pages(:home_page).url,
          capture_time: now,
          body_url: 'http://example.com',
          # Use an invalid hash to test that it was actually read and verified.
          hash: 'abc',
          source_type: 'test_source',
          source_metadata: { test_meta: 'data' }
        }
      ].map(&:to_json).join("\n")
    )
    ImportVersionsJob.perform_now(import)

    assert_equal(page_versions_count, pages(:home_page).versions.count)
    assert_nil(pages(:home_page).versions.where(capture_time: now).first)
    assert_any_includes(import.processing_errors, 'hash')
  end

  test 'allows "version_hash" instead of "body_hash"' do
    page_versions_count = pages(:home_page).versions.count
    now = Time.now

    stub_request(:any, 'http://example.com')
      .to_return(body: 'Hello!', status: 200)

    import = Import.create_with_data(
      {
        user: users(:alice)
      },
      [
        {
          url: pages(:home_page).url,
          capture_time: now,
          body_url: 'http://example.com',
          # Use an invalid hash to test that it was actually read and verified.
          version_hash: 'abc',
          source_type: 'test_source',
          source_metadata: { test_meta: 'data' }
        }
      ].map(&:to_json).join("\n")
    )
    ImportVersionsJob.perform_now(import)

    assert_equal(page_versions_count, pages(:home_page).versions.count)
    assert_nil(pages(:home_page).versions.where(capture_time: now).first)
    assert_any_includes(import.processing_errors, 'hash')
  end

  test 'gets content_length from archiver' do
    page_versions_count = pages(:home_page).versions.count
    now = Time.now
    hash = 'fd9b8b0e5e12450cae7c43aba3209ffc54bf5cbcb4bcaf70287d9201c6845d1d'

    stub_request(:any, 'http://example.com')
      .to_return(body: 'Hello!😀', status: 200)

    import = Import.create_with_data(
      {
        user: users(:alice)
      },
      [
        # Import two versions with the same hash to make sure we get the right
        # length regardless of whether we downloaded fresh content.
        {
          url: pages(:home_page).url,
          capture_time: now - 1.second,
          body_url: 'http://example.com',
          body_hash: hash
        },
        {
          url: pages(:home_page).url,
          capture_time: now,
          body_url: 'http://example.com',
          body_hash: hash
        }
      ].map(&:to_json).join("\n")
    )
    ImportVersionsJob.perform_now(import)
    puts import.processing_errors
    assert_equal(page_versions_count + 2, pages(:home_page).versions.count)

    version_b, version_a = pages(:home_page).versions.order(created_at: :desc).limit(2)
    assert_equal(10, version_a.content_length, 'the `content_length` property should match the body byte length')
    assert_equal(10, version_b.content_length, 'the `content_length` property should match the body byte length when loaded from storage')
  end

  test 'normalizes media_type' do
    now = Time.now
    import = Import.create_with_data(
      {
        user: users(:alice)
      },
      [
        {
          url: pages(:home_page).url,
          capture_time: now - 1.second,
          body_url: 'https://test-bucket.s3.amazonaws.com/whatever',
          body_hash: 'abc',
          media_type: 'text/HTML'
        }
      ].map(&:to_json).join("\n")
    )
    ImportVersionsJob.perform_now(import)
    puts import.processing_errors

    version = pages(:home_page).latest
    assert_equal('text/html', version.media_type)
  end

  test 'allows "uri" instead of "body_url" for backwards-compatibility' do
    now = Time.now.round
    body_url = 'https://test-bucket.s3.amazonaws.com/example-v1'

    stub_request(:any, body_url)
      .to_return(body: 'Hello!', status: 200)

    import = Import.create_with_data(
      {
        user: users(:alice)
      },
      [
        {
          url: pages(:home_page).url,
          capture_time: now,
          uri: body_url,
          source_type: 'test_source',
          source_metadata: { test_meta: 'data' }
        }
      ].map(&:to_json).join("\n")
    )
    ImportVersionsJob.perform_now(import)

    new_version = pages(:home_page).versions.where(capture_time: now).first
    assert_equal(body_url, new_version.body_url)
  end

  test 'adds URL to an existing page if the version was matched to a page with a different URL' do
    url_a = 'https://example.gov/office'
    url_b = 'http://example.gov/office/'

    page = Page.create(url: url_a)
    import = Import.create_with_data(
      { user: users(:alice) },
      [
        {
          url: url_b,
          capture_time: Time.now - 1.second,
          body_url: 'https://test-bucket.s3.amazonaws.com/whatever',
          body_hash: 'abc'
        }
      ].map(&:to_json).join("\n")
    )
    ImportVersionsJob.perform_now(import)

    assert_equal(1, page.versions.count, 'Version was added to the right page')
    assert_equal(
      [url_a, url_b].sort,
      page.urls.pluck(:url).sort,
      'New URL was added to the page'
    )
  end
end
