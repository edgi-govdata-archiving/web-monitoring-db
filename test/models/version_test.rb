require 'test_helper'

class VersionTest < ActiveSupport::TestCase
  test 'previous should get the previous version' do
    previous = versions(:page2_v2).previous
    assert_equal versions(:page2_v1), previous, 'Previous returned the wrong version'
  end

  test 'ensure change from previous should always return a change object (even if unpersisted)' do
    change = versions(:page2_v2).ensure_change_from_previous
    assert_not_nil change
  end

  test 'next should get the next version' do
    next_version = versions(:page1_v1).next
    assert_equal versions(:page1_v2), next_version, 'Next returned the wrong version'
  end

  test 'ensure change from next should always return a change object (even if unpersisted)' do
    change = versions(:page2_v1).ensure_change_from_next
    assert_not_nil change
  end

  test 'update_different_attribute' do
    page = Page.create(url: 'http://somerandomsite.com/')
    a1 = page.versions.create(source_type: 'a', version_hash: 'abc', capture_time: Time.now - 3.days)
    b1 = page.versions.create(source_type: 'b', version_hash: 'abc', capture_time: Time.now - 2.9.days)
    a1.update_different_attribute
    b1.update_different_attribute
    assert(a1.different?, 'The first version is different')
    assert(b1.different?, 'The first version of a given source_type is different')

    a2 = page.versions.create(source_type: 'a', version_hash: 'abc', capture_time: Time.now - 1.days)
    b2 = page.versions.create(source_type: 'b', version_hash: 'abc', capture_time: Time.now - 0.9.days)
    a2.update_different_attribute
    b2.update_different_attribute
    assert_not(a2.different?, 'A version with the same hash is not different')
    assert_not(b2.different?, 'A version of a given source_type with the same hash is not different')

    a3 = page.versions.create(source_type: 'a', version_hash: 'def', capture_time: Time.now - 2.days)
    b3 = page.versions.create(source_type: 'b', version_hash: 'def', capture_time: Time.now - 1.9.days)
    a3.update_different_attribute
    b3.update_different_attribute
    assert(a3.different?, 'A version with a different hash is different')
    assert(b3.different?, 'A version of a given source_type with a different hash is different')
    assert(Version.find(a2.uuid).different?, 'Updating a version inserted before an existing version updates the existing version, too')
    assert(Version.find(b2.uuid).different?, 'Updating a version inserted before an existing version updates the existing version for a given source_type, too')
  end

  test 'version titles should be single lines with no outside spaces' do
    version = Version.create(
      page: pages(:home_page),
      capture_time: '2017-03-01T00:00:00Z',
      version_hash: 'icanputanythingheremwahahahaha',
      title: "   This is \n\n the title  \n "
    )
    assert_equal('This is the title', version.title, 'The title was not normalized')
  end
end
