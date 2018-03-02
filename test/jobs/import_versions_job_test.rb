require 'test_helper'

class ImportVersionsJobTest < ActiveJob::TestCase
  def setup
    @original_allowed_hosts = Archiver.allowed_hosts
    Archiver.allowed_hosts = ['https://test-bucket.s3.amazonaws.com']
  end

  def teardown
    Archiver.allowed_hosts = @original_allowed_hosts
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
      ].map(&:to_json).join("\n")
    )
    ImportVersionsJob.perform_now(import)

    assert_equal(page_versions_count, pages(:home_page).versions.count)
    assert_equal(original_data['version_hash'], versions(:page1_v1).version_hash, 'version_hash was changed')
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
          page_url: pages(:home_page).url,
          page_title: pages(:home_page).title,
          site_agency: 'The Federal Example Agency',
          site_name: pages(:home_page).site,
          capture_time: versions(:page1_v5).capture_time,
          # NOTE: `uri` is left out intentionally; it should get set to nil
          version_hash: 'INVALID_HASH',
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
    assert_nil(version.uri, 'uri was not changed')
    assert_equal('INVALID_HASH', version.version_hash, 'version_hash was not changed')
    assert_equal({ 'test_meta' => 'data' }, version.source_metadata, 'source_metadata was not replaced')
  end

  test 'merges with an existing version if requested' do
    page_versions_count = pages(:home_page).versions.count
    original_uri = versions(:page1_v5).uri
    original_meta = versions(:page1_v5).source_metadata

    import = Import.create_with_data(
      {
        user: users(:alice),
        update_behavior: :merge
      },
      [
        {
          page_url: pages(:home_page).url,
          page_title: pages(:home_page).title,
          site_agency: 'The Federal Example Agency',
          site_name: pages(:home_page).site,
          capture_time: versions(:page1_v5).capture_time,
          # NOTE: uri is intentionally left out; it should not get set to nil
          version_hash: 'INVALID_HASH',
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
    assert_equal(original_uri, version.uri, 'uri was changed')
    assert_equal('INVALID_HASH', version.version_hash, 'version_hash was not changed')
    expected_meta = original_meta.merge('test_meta' => 'data')
    assert_equal(expected_meta, version.source_metadata, 'source_metadata was not merged')
  end

  test 'raises helpful error if page_url is missing' do
    import = Import.create_with_data(
      {
        user: users(:alice),
        update_behavior: :merge
      },
      [
        {
          # omitted page_url
          page_title: pages(:home_page).title,
          site_agency: 'The Federal Example Agency',
          site_name: pages(:home_page).site,
          capture_time: versions(:page1_v5).capture_time,
          # NOTE: uri is intentionally left out; it should not get set to nil
          version_hash: 'INVALID_HASH',
          source_type: versions(:page1_v5).source_type,
          source_metadata: { test_meta: 'data' }
        }
      ].map(&:to_json).join("\n")
    )
    ImportVersionsJob.perform_now(import)
    assert_equal(['Row 0: `page_url` is missing'], import.processing_errors, 'expected error due to missing page_url')
  end
end
