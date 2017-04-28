require 'test_helper'
require_dependency Rails.root.join('lib/archiver/stores/s3')

class Archiver::Stores::S3Test < ActiveSupport::TestCase
  def test_storage
    Archiver::Stores::S3.new(
      key: 'whatever',
      secret: 'test',
      bucket: 'test-bucket',
      region: 'us-west-2'
    )
  end

  test 's3 storage can parse S3 URIs' do
    parsed = test_storage.parse_s3_url('s3://test-bucket/some/thing.txt')
    assert_equal 'test-bucket', parsed[:bucket]
    assert_equal 'some/thing.txt', parsed[:path]
    assert_nil parsed[:region]
  end

  test 's3 storage can parse S3 URLs' do
    bucket_hostname_url = test_storage.parse_s3_url('https://test-bucket.s3.amazonaws.com/some/thing.txt')
    assert_equal 'test-bucket', bucket_hostname_url[:bucket]
    assert_equal 'some/thing.txt', bucket_hostname_url[:path]
    assert_nil bucket_hostname_url[:region]

    bucket_path_url = test_storage.parse_s3_url('https://s3.amazonaws.com/test-bucket/some/thing.txt')
    assert_equal 'test-bucket', bucket_path_url[:bucket]
    assert_equal 'some/thing.txt', bucket_path_url[:path]
    assert_nil bucket_path_url[:region]

    region_url = test_storage.parse_s3_url('https://s3-us-west-2.amazonaws.com/test-bucket/some/thing.txt')
    assert_equal 'test-bucket', region_url[:bucket]
    assert_equal 'some/thing.txt', region_url[:path]
    assert_equal 'us-west-2', region_url[:region]
  end

  test 's3 storage will not parse non-S3 URLs' do
    parsed = test_storage.parse_s3_url('https://google.com/some/thing.txt')
    assert_nil parsed
  end

  test 's3 storage can determine whether an S3 URI matches it' do
    storage = test_storage
    assert storage.contains_url?('s3://test-bucket/something.txt')
    assert_not storage.contains_url?('s3://other-bucket/something.txt')
  end

  test 's3 storage can determine whether an S3 URL matches it' do
    storage = test_storage
    assert storage.contains_url?('https://test-bucket.s3.amazonaws.com/something.txt')
    assert_not storage.contains_url?('https://other-bucket.s3.amazonaws.com/something.txt')
  end
end
