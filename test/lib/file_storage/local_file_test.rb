require 'test_helper'
include ActionDispatch::Routing::UrlFor
include Rails.application.routes.url_helpers

class FileStorage::LocalFileTest < ActiveSupport::TestCase
  storage_path = Rails.root.join('tmp/test/storage')

  def setup
    @storage = nil
  end

  def storage(options = {})
    @storage ||= FileStorage::LocalFile.new(options)
  end

  test 'can save a file' do
    FileStorage::LocalFile.new.save_file 'abc', 'xyz'
    FileStorage::LocalFile.new(path: storage_path).save_file 'abc', 'xyz'
  end

  test 'can get a file' do
    storage.save_file 'abc', 'xyz'
    assert_equal 'xyz', storage.get_file('abc'), 'The retrieved file did not match what was saved'
  end

  test 'correctly matches file URLs' do
    storage.save_file 'abc', 'xyz'
    url = storage.url_for_file 'abc'
    assert storage.contains_url?(url)
  end

  test 'does not match external URLs' do
    assert_not storage.contains_url?('http://somewhere.com')
  end

  test 'does not match non-existant local URLs' do
    nowhere_url = polymorphic_url('api_v0_raw', id: 'nowhere')
    assert_not storage.contains_url?(nowhere_url)
  end

  test 'does not match file URLs' do
    assert_not storage.contains_url?('file:///nowhere')
  end

  test 'can generate a local URL' do
    whatever_url = polymorphic_url('api_v0_raw', id: 'whatever')
    assert_equal whatever_url, storage(path: storage_path).url_for_file('whatever')
  end
end
