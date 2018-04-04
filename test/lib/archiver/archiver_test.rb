require 'test_helper'

class Archiver::ArchiverTest < ActiveSupport::TestCase
  def setup
    @original_storage = Archiver.store
    Archiver.store = FileStorage::LocalFile.new(path: Rails.root.join('tmp/test/storage'))
  end

  def teardown
    Archiver.store = @original_storage
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
end
