require 'test_helper'

class FileStorage::S3Test < ActiveSupport::TestCase
  def example_storage
    FileStorage::S3.new(
      key: 'whatever',
      secret: 'test',
      bucket: 'test-bucket',
      region: 'us-west-2'
    )
  end

  def gzip_text(input)
    stream = Zlib::GzipWriter.new(StringIO.new)
    stream << input
    stream.close.string
  end

  test 's3 storage can parse S3 URIs' do
    parsed = example_storage.send :parse_s3_url, 's3://test-bucket/some/thing.txt'
    assert_equal 'test-bucket', parsed[:bucket]
    assert_equal 'some/thing.txt', parsed[:path]
    assert_nil parsed[:region]
  end

  test 's3 storage can parse S3 URLs' do
    bucket_hostname_url = example_storage.send :parse_s3_url, 'https://test-bucket.s3.amazonaws.com/some/thing.txt'
    assert_equal 'test-bucket', bucket_hostname_url[:bucket]
    assert_equal 'some/thing.txt', bucket_hostname_url[:path]
    assert_nil bucket_hostname_url[:region]

    bucket_path_url = example_storage.send :parse_s3_url, 'https://s3.amazonaws.com/test-bucket/some/thing.txt'
    assert_equal 'test-bucket', bucket_path_url[:bucket]
    assert_equal 'some/thing.txt', bucket_path_url[:path]
    assert_nil bucket_path_url[:region]

    region_url = example_storage.send :parse_s3_url, 'https://s3-us-west-2.amazonaws.com/test-bucket/some/thing.txt'
    assert_equal 'test-bucket', region_url[:bucket]
    assert_equal 'some/thing.txt', region_url[:path]
    assert_equal 'us-west-2', region_url[:region]
  end

  test 's3 storage will not parse non-S3 URLs' do
    parsed = example_storage.send :parse_s3_url, 'https://google.com/some/thing.txt'
    assert_nil parsed
  end

  test 's3 storage can determine whether an S3 URI matches it' do
    stub_request(:head, 'https://test-bucket.s3.us-west-2.amazonaws.com/something.txt')
      .to_return(status: 200, body: '', headers: {})
    stub_request(:head, 'https://test-bucket.s3.us-west-2.amazonaws.com/does-not-exist.txt')
      .to_return(status: 404, body: '', headers: {})

    storage = example_storage
    assert storage.contains_url?('s3://test-bucket/something.txt')
    assert_not storage.contains_url?('s3://test-bucket/does-not-exist.txt')
    # No stub because no request should be made (it's in the wrong bucket)
    assert_not storage.contains_url?('s3://other-bucket/something.txt')
  end

  test 's3 storage can determine whether an S3 URL matches it' do
    stub_request(:head, 'https://test-bucket.s3.us-west-2.amazonaws.com/something.txt')
      .to_return(status: 200, body: '', headers: {})
    stub_request(:head, 'https://test-bucket.s3.us-west-2.amazonaws.com/does-not-exist.txt')
      .to_return(status: 404, body: '', headers: {})

    storage = example_storage
    assert storage.contains_url?('https://test-bucket.s3.amazonaws.com/something.txt')
    assert_not storage.contains_url?('s3://test-bucket/does-not-exist.txt')
    # No stub because no request should be made (it's in the wrong bucket)
    assert_not storage.contains_url?('https://other-bucket.s3.amazonaws.com/something.txt')
  end

  test 'can generate a URL' do
    whatever_url = example_storage.url_for_file('whatever')
    assert_equal 'https://test-bucket.s3.amazonaws.com/whatever', whatever_url
  end

  test 's3 storage can get a file' do
    stub_request(:get, 'https://test-bucket.s3.us-west-2.amazonaws.com/something.txt')
      .to_return(status: 200, body: 'Hello from S3!', headers: {})

    storage = example_storage
    assert_equal 'Hello from S3!', storage.get_file('https://test-bucket.s3.amazonaws.com/something.txt')
  end

  test 's3 storage can get a gzipped file' do
    stub_request(:get, 'https://test-bucket.s3.us-west-2.amazonaws.com/something.txt')
      .to_return(status: 200, body: gzip_text('Hello from S3!'), headers: { 'Content-Encoding' => 'gzip' })

    storage = example_storage
    assert_equal 'Hello from S3!', storage.get_file('https://test-bucket.s3.amazonaws.com/something.txt')
  end
end
