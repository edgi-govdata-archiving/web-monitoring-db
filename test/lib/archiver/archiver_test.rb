require 'test_helper'

class Archiver::ArchiverTest < ActiveSupport::TestCase
  def setup
    @original_storage = Archiver.store
    path = Rails.root.join('tmp/test/storage')
    FileUtils.remove_dir(path, force: true)
    Archiver.store = FileStorage::LocalFile.new(path: path)
  end

  def teardown
    Archiver.store = @original_storage
    WebMock.reset!
  end

  test 'it saves the URL by its hash' do
    hash = '334d016f755cd6dc58c53a86e183882f8ec14f52fb05345887c8a5edd42c87b7'
    stub_request(:any, 'http://example.com')
      .to_return(body: 'Hello!', status: 200)

    result = Archiver.archive('http://example.com')
    expected_url = "file://#{Rails.root.join('tmp/test/storage', hash)}"
    assert_equal(expected_url, result[:url])
    assert_equal(hash, result[:hash])
    assert_equal('Hello!', Archiver.store.get_file(hash))
  end

  test 'it accepts an expected hash' do
    hash = '334d016f755cd6dc58c53a86e183882f8ec14f52fb05345887c8a5edd42c87b7'
    stub_request(:any, 'http://example.com')
      .to_return(body: 'Hello!', status: 200)

    Archiver.archive('http://example.com', expected_hash: hash)
    assert_equal('Hello!', Archiver.store.get_file(hash))
  end

  test 'raises if response does not match expected hash' do
    stub_request(:any, 'http://example.com')
      .to_return(body: 'Hello!', status: 200)

    assert_raises(Api::ApiError) do
      Archiver.archive('http://example.com', expected_hash: 'abc')
    end
  end

  test 'it should retry on HTTP errors and gateway errors' do
    request = stub_request(:get, 'http://example.com')
      .to_return(body: 'Gateway Error', status: 503).then
      .to_return(body: 'Hello!', status: 200)

    result = Archiver.archive('http://example.com')
    assert_requested(request, times: 2)
    assert_equal('Hello!', Archiver.store.get_file(result[:hash]))
  end

  test 'it should save error content after the maximum number of retries' do
    request = stub_request(:get, 'http://example.com')
      .to_return(body: 'Gateway Error', status: 503).times(3)

    result = Archiver.archive('http://example.com')
    assert_requested(request, times: 3)
    assert_equal('Gateway Error', Archiver.store.get_file(result[:hash]))
  end

  test 'it hashes the content at a URL' do
    hash = '334d016f755cd6dc58c53a86e183882f8ec14f52fb05345887c8a5edd42c87b7'
    stub_request(:any, 'http://example.com')
      .to_return(body: 'Hello!', status: 200)

    result = Archiver.hash_content_at_url('http://example.com')
    assert_equal(hash, result)
  end
end
