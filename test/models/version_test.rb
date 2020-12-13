require 'test_helper'

class VersionTest < ActiveSupport::TestCase
  test 'previous should get the previous `different` version' do
    previous = versions(:page2_v2).previous
    assert_equal versions(:page2_v1), previous, 'Previous returned the wrong version'
  end

  test 'previous(different: false) should get the previous version regardless of its `different` value' do
    page = pages(:home_page)
    v1 = page.versions.create!(capture_time: Time.now + 1.minute, version_hash: 'abc')
    v1.update_different_attribute
    v2 = page.versions.create!(capture_time: Time.now + 2.minutes, version_hash: 'abc')
    v2.update_different_attribute
    v3 = page.versions.create!(capture_time: Time.now + 3.minutes, version_hash: 'abc')
    v3.update_different_attribute

    assert_predicate(v1, :different?)
    assert_not_predicate(v2, :different?)
    assert_not_predicate(v3, :different?)
    assert_equal(v2.uuid, v3.previous(different: false).uuid, 'Previous should have been the previous version (which was NOT different)')

    # Change whether v2 was different to test that `different: false` *ignores* difference.
    v2.update!(version_hash: 'def')
    v2.update_different_attribute
    v3.reload
    assert_predicate(v2, :different?)
    assert_predicate(v3, :different?)
    assert_equal(v2.uuid, v3.previous(different: false).uuid, 'Previous should have been the previous version (which WAS different)')
  end

  test 'ensure change from previous should always return a change object (even if unpersisted)' do
    change = versions(:page2_v2).ensure_change_from_previous
    assert_not_nil change
  end

  test 'next should get the next `different` version' do
    next_version = versions(:page1_v1).next
    assert_equal versions(:page1_v2), next_version, 'Next returned the wrong version'
  end

  test 'next(different: false) should get the next version regardless of its `different` value' do
    page = pages(:home_page)
    v1 = page.versions.create!(capture_time: Time.now + 1.minute, version_hash: 'abc')
    v1.update_different_attribute
    v2 = page.versions.create!(capture_time: Time.now + 2.minutes, version_hash: 'abc')
    v2.update_different_attribute
    v3 = page.versions.create!(capture_time: Time.now + 3.minutes, version_hash: 'abc')
    v3.update_different_attribute

    assert_predicate(v1, :different?)
    assert_not_predicate(v2, :different?)
    assert_not_predicate(v3, :different?)
    assert_equal(v2.uuid, v1.next(different: false).uuid, 'Next should have been the next version (which was NOT different)')

    # Change whether v2 was different to test that `different: false` *ignores* difference.
    v2.update!(version_hash: 'def')
    v2.update_different_attribute
    assert_predicate(v2, :different?)
    assert_equal(v2.uuid, v1.next(different: false).uuid, 'Next should have been the next version (which WAS different)')
  end

  test 'ensure change from next should always return a change object (even if unpersisted)' do
    change = versions(:page2_v1).ensure_change_from_next
    assert_not_nil change
  end

  test 'update_different_attribute' do
    page = Page.create(url: 'http://somerandomsite.com/')
    a1 = page.versions.create(source_type: 'a', version_hash: 'abc', capture_time: Time.now - 3.days)
    b1 = page.versions.create(source_type: 'b', version_hash: 'abc', capture_time: Time.now - 2.days)
    a1.update_different_attribute
    b1.update_different_attribute
    assert(a1.different?, 'The first version should have been different')
    assert_not(b1.different?, 'The second version should not have been different')

    a2 = page.versions.create(source_type: 'a', version_hash: 'def', capture_time: Time.now - 2.5.days)
    a2.update_different_attribute
    assert(a2.different?, 'A version with a different hash is different')
    assert(Version.find(b1.uuid).different?, 'Updating a version inserted before an existing version updates the existing version, too')
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

  test 'version status must be a valid status code or nil' do
    version = versions(:page1_v1)
    version.status = nil
    assert(version.valid?, 'A nil status was not valid')

    version.status = 200
    assert(version.valid?, 'A 200 status was not valid')

    version.status = 1000
    assert_not(version.valid?, 'A 1000 status was valid')

    version.status = 'whats this now'
    assert_not(version.valid?, 'A text status was valid')
  end

  test 'basic media types are valid' do
    version = Version.new(page: Page.new, media_type: 'text/plain')
    assert(version.valid?, 'A common media type should be valid')
  end

  test 'media_type cannot include parameters' do
    version = Version.new(page: Page.new, media_type: 'text/plain; charset=utf-8')
    assert_not(version.valid?, 'A media type with parameters should not be valid')
    assert_includes(version.errors, :media_type)
  end

  test 'media_type is always lower-case' do
    version = Version.new
    version.media_type = 'text/HTML'
    assert_equal('text/html', version.media_type)
  end

  test 'media_type changes known synonyms to their canonical version' do
    version = Version.new(media_type: 'application/html')
    assert_equal('text/html', version.media_type)

    version.media_type = 'application/xhtml'
    assert_equal('application/xhtml+xml', version.media_type)
  end

  test 'media_type is extracted from headers if not set' do
    version = Version.create(
      page: pages(:home_page),
      capture_time: '2017-03-01T00:00:00Z',
      source_metadata: {
        'headers' => { 'Content-Type' => 'text/plain; charset=utf-8' }
      }
    )
    assert_equal('text/plain', version.media_type)
  end

  test 'content_length cannot be negative' do
    version = Version.new(page: Page.new, content_length: 10)
    assert(version.valid?, 'A positive content_length should be valid')

    version = Version.new(page: Page.new, content_length: -10)
    assert_not(version.valid?, 'A negative content_length should not be valid')
    assert_includes(version.errors, :content_length)
  end
end
