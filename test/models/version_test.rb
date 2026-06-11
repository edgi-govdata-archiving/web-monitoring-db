# frozen_string_literal: true

require 'test_helper'

class VersionTest < ActiveSupport::TestCase
  test 'previous should get the previous `different` version' do
    previous = versions(:page2_v2).previous
    assert_equal versions(:page2_v1), previous, 'Previous returned the wrong version'
  end

  test 'previous(different: false) should get the previous version regardless of its `different` value' do
    page = pages(:home_page)
    v1 = page.versions.create!(capture_time: 1.minute.from_now, body_hash: 'abc')
    v1.update_different_attribute
    v2 = page.versions.create!(capture_time: 2.minutes.from_now, body_hash: 'abc')
    v2.update_different_attribute
    v3 = page.versions.create!(capture_time: 3.minutes.from_now, body_hash: 'abc')
    v3.update_different_attribute

    assert_predicate(v1, :different?)
    assert_not_predicate(v2, :different?)
    assert_not_predicate(v3, :different?)
    assert_equal(v2.uuid, v3.previous(different: false).uuid, 'Previous should have been the previous version (which was NOT different)')

    # Change whether v2 was different to test that `different: false` *ignores* difference.
    v2.update!(body_hash: 'def')
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
    v1 = page.versions.create!(capture_time: 1.minute.from_now, body_hash: 'abc')
    v1.update_different_attribute
    v2 = page.versions.create!(capture_time: 2.minutes.from_now, body_hash: 'abc')
    v2.update_different_attribute
    v3 = page.versions.create!(capture_time: 3.minutes.from_now, body_hash: 'abc')
    v3.update_different_attribute

    assert_predicate(v1, :different?)
    assert_not_predicate(v2, :different?)
    assert_not_predicate(v3, :different?)
    assert_equal(v2.uuid, v1.next(different: false).uuid, 'Next should have been the next version (which was NOT different)')

    # Change whether v2 was different to test that `different: false` *ignores* difference.
    v2.update!(body_hash: 'def')
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
    a1 = page.versions.create(source_type: 'a', body_hash: 'abc', capture_time: 3.days.ago)
    b1 = page.versions.create(source_type: 'b', body_hash: 'abc', capture_time: 2.days.ago)
    a1.update_different_attribute
    b1.update_different_attribute
    assert(a1.different?, 'The first version should have been different')
    assert_not(b1.different?, 'The second version should not have been different')

    a2 = page.versions.create(source_type: 'a', body_hash: 'def', capture_time: 2.5.days.ago)
    a2.update_different_attribute
    assert(a2.different?, 'A version with a different hash is different')
    assert(Version.find(b1.uuid).different?, 'Updating a version inserted before an existing version updates the existing version, too')
  end

  test 'version titles should be single lines with no outside spaces' do
    version = Version.create(
      page: pages(:home_page),
      capture_time: '2017-03-01T00:00:00Z',
      body_hash: 'icanputanythingheremwahahahaha',
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

  test 'version header names are always lower-case strings' do
    version = Version.create(
      page: pages(:home_page),
      capture_time: '2017-03-01T00:00:00Z',
      headers: { 'Content-Type': 'text/plain' }
    )
    assert_equal({ 'content-type' => 'text/plain' }, version.headers)
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
      headers: { 'Content-Type' => 'text/plain; charset=utf-8' }
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

  test 'content_length is extracted from headers if not set' do
    version = Version.create(
      page: pages(:home_page),
      capture_time: '2017-03-01T00:00:00Z',
      headers: { 'Content-Length' => '10342' }
    )
    assert_equal(10_342, version.content_length)
  end

  test 'effective_status considers redirects to be ok' do
    version = Version.create(
      page: pages(:home_page),
      capture_time: '2017-03-01T00:00:00Z',
      status: 200,
      url: 'https://hazards.fema.gov/nri/take-action',
      source_metadata: {
        redirects: [
          'https://hazards.fema.gov/nri/take-action',
          'https://www.fema.gov/emergency-managers/practitioners/resilience-analysis-and-planning-tool'
        ]
      },
      title: ''
    )
    assert_equal(200, version.effective_status)
  end

  test 'effective_status considers redirects to root as 404' do
    version = Version.create(
      page: pages(:home_page),
      capture_time: '2017-03-01T00:00:00Z',
      url: 'https://waterdata.usgs.gov/nwis',
      status: 200,
      source_metadata: {
        redirects: [
          'https://waterdata.usgs.gov/nwis',
          'https://waterdata.usgs.gov/'
        ]
      },
      title: ''
    )
    assert_equal(404, version.effective_status)
  end

  test 'effective_status considers redirects to root-like paths as 404' do
    version = Version.create(
      page: pages(:home_page),
      capture_time: '2017-03-01T00:00:00Z',
      url: 'https://eta.lbl.gov/justice-40',
      status: 200,
      source_metadata: {
        redirects: [
          'https://eta.lbl.gov/justice-40',
          'https://eta.lbl.gov/home'
        ]
      },
      title: ''
    )
    assert_equal(404, version.effective_status)
  end

  test 'effective_status considers redirects to cross-domain root as ok' do
    version = Version.create(
      page: pages(:home_page),
      capture_time: '2017-03-01T00:00:00Z',
      url: 'https://waterdata.usgs.gov/nwis',
      status: 200,
      source_metadata: {
        redirects: [
          'https://waterdata.usgs.gov/nwis',
          'https://www.usgs.gov/'
        ]
      },
      title: ''
    )
    assert_equal(200, version.effective_status)
  end

  test 'effective_status considers redirects to EPA climate signpost page as 404' do
    version = Version.create(
      page: pages(:home_page),
      capture_time: '2017-03-01T00:00:00Z',
      url: 'https://www3.epa.gov/climatechange/kids/solutions/index.html',
      status: 200,
      source_metadata: {
        redirects: [
          'https://www3.epa.gov/climatechange/kids/solutions/index.html',
          'https://www.epa.gov/sites/production/files/signpost/cc.html'
        ]
      },
      title: ''
    )
    assert_equal(404, version.effective_status)
  end

  test 'effective_status considers redirects to climate.nasa.gov to science.nasa.gov/climage-change as 404' do
    version = Version.create(
      page: pages(:home_page),
      capture_time: '2017-03-01T00:00:00Z',
      url: 'https://climate.nasa.gov/explore/ask-nasa-climate/183/the-year-without-a-summer/',
      status: 200,
      source_metadata: {
        redirects: [
          'https://climate.nasa.gov/explore/ask-nasa-climate/183/the-year-without-a-summer/',
          'https://science.nasa.gov/climate-change/'
        ]
      },
      title: ''
    )
    assert_equal(404, version.effective_status)
  end

  test 'effective_status considers redirects to unblock.federalregister.gov as 429' do
    version = Version.create(
      page: pages(:home_page),
      capture_time: '2017-03-01T00:00:00Z',
      url: 'https://www.federalregister.gov/documents/2021/07/27/2021-15122/national-oil-and-hazardous-substances-pollution-contingency-plan-monitoring-requirements-for-use-of',
      status: 200,
      source_metadata: {
        redirects: [
          'https://www.federalregister.gov/documents/2021/07/27/2021-15122/national-oil-and-hazardous-substances-pollution-contingency-plan-monitoring-requirements-for-use-of',
          'https://unblock.federalregister.gov/'
        ]
      },
      title: ''
    )
    assert_equal(429, version.effective_status)
  end
end
