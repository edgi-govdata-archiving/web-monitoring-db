# frozen_string_literal: true

require 'test_helper'

class FileStorage::LocalFileTest < ActiveSupport::TestCase
  storage_path = Rails.root.join('tmp/test/storage')

  setup do
    @storage = nil
  end

  def storage(**)
    @storage ||= FileStorage::LocalFile.new(**)
  end

  test 'can save a file' do
    temp_storage = FileStorage::LocalFile.new
    temp_storage.save_file 'abc', 'xyz'
    assert_equal 'xyz', File.read(File.join(temp_storage.directory, 'abc'))
  end

  test 'can save a file in a configured location' do
    storage(path: storage_path).save_file 'abc', 'xyz'
    assert_equal 'xyz', File.read("#{storage_path}/abc")
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

  test 'does not match non-file URLs' do
    assert_not storage.contains_url?('http://somewhere.com')
  end

  test 'does not match file URLs that are not in its directory' do
    assert_not storage.contains_url?('file:///nowhere')
  end

  test 'can generate a file URL' do
    whatever_url = "file://#{storage_path.join 'whatever'}"
    assert_equal whatever_url, storage(path: storage_path).url_for_file('whatever')
  end
end
