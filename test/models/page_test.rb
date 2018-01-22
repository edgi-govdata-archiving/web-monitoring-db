require 'test_helper'

class PageTest < ActiveSupport::TestCase
  test 'page urls should always have a protocol' do
    page = Page.create(url: 'www.example.com/whatever')
    assert_equal('http://www.example.com/whatever', page.url, 'The URL was not given a protocol')

    page = Page.create(url: 'https://www.example.com/whatever')
    assert_equal('https://www.example.com/whatever', page.url, 'The URL was modified unnecessarily')
  end

  test 'page urls without a domain should be invalid' do
    page = Page.create(url: 'some/path/to/a/page')
    assert_not(page.valid?, 'The page should be invalid because it has no domain')
  end

  test 'page title should sync with title from version with most recent capture time' do
    page = pages(:home_page)
    assert_equal('Page One', page.title)

    page.versions.create(title: 'Newest Version', capture_time: '2017-03-05T00:00:00Z')
    refute(page.changed?, 'The page was left with unsaved changes')
    assert_equal('Newest Version', page.title, 'The page title should always sync against the title of the version with the most recent capture time')
    page.versions.create(title: 'Older Version', capture_time: '2017-03-01T00:00:00Z')
    refute(page.changed?, 'The page was left with unsaved changes')
    refute_equal('Older Version', page.title, 'The page title should not sync against the title of a newly created version with an older capture time')
  end

  test "page title should not sync with a version's title if it's nil or blank" do
    page = pages(:home_page)
    assert_equal('Page One', page.title)

    page.versions.create(capture_time: '2017-03-05T00:00:00Z')
    refute(page.changed?, 'The page was left with unsaved changes')
    assert_equal('Page One', page.title, 'The page title should not sync with the incoming version if it has a nil title')
    page.versions.create(title: '', capture_time: '2017-03-05T00:00:00Z')
    refute(page.changed?, 'The page was left with unsaved changes')
    assert_equal('Page One', page.title, 'The page title should not sync with the incoming version if it has an empty title')
  end

  test 'can add a page to many agency models' do
    pages(:home_page).add_to_agency(agencies(:epa))
    pages(:home_page).add_to_agency(agencies(:doi))
    assert pages(:home_page).agencies.find(agencies(:epa).uuid)
    assert pages(:home_page).agencies.find(agencies(:doi).uuid)
  end

  test 'can add a page to an agency by name' do
    pages(:home_page).add_to_agency('EPA')
    assert pages(:home_page).agencies.find(agencies(:epa).uuid)
  end

  test 'adding a page to an unknown agency creates that agency' do
    pages(:home_page).add_to_agency('Department of Unicorns')
    unicorns = Agency.find_by!(name: 'Department of Unicorns')
    assert pages(:home_page).agencies.include?(unicorns)
  end

  test 'adding a page to an agency repeatedly does not cause errors or duplicates' do
    pages(:home_page).add_to_agency('EPA')
    pages(:home_page).add_to_agency(agencies(:epa))

    assert_equal(1, pages(:home_page).agencies.count)
  end

  test 'can add a page to many site models' do
    pages(:home_page).add_to_site(sites(:all_epa))
    pages(:home_page).add_to_site(sites(:epa_compliance))
    assert pages(:home_page).sites.find(sites(:all_epa).uuid)
    assert pages(:home_page).sites.find(sites(:epa_compliance).uuid)
  end

  test 'can add a page to a site by name' do
    pages(:home_page).add_to_site('EPA - epa.gov')
    assert pages(:home_page).sites.find(sites(:all_epa).uuid)
  end

  test 'adding a page to an unknown site creates that site' do
    pages(:home_page).add_to_site('Unicorns.gov Site')
    unicorns = Site.find_by!(name: 'Unicorns.gov Site')
    assert pages(:home_page).sites.include?(unicorns)
  end

  test 'adding a page to a site repeatedly does not cause errors or duplicates' do
    pages(:home_page).add_to_site('EPA - epa.gov')
    pages(:home_page).add_to_site(sites(:all_epa))

    assert_equal(1, pages(:home_page).sites.count)
  end

  test 'can add a page to a site by versionista ID' do
    pages(:home_page).add_to_site('Magical River Protectors', versionista_id: 5)
    assert pages(:home_page).sites.include?(sites(:all_epa))
    assert_equal('Magical River Protectors', sites(:all_epa).name, 'Site name was not updated')
  end

  test 'add a page to a site by an unknown versionista ID creates the site' do
    pages(:home_page).add_to_site('Magical River Protectors', versionista_id: 10)
    river_protectors = Site.find_by!(versionista_id: 10)
    assert_equal('Magical River Protectors', river_protectors.name, 'New site did not have a name')
    assert pages(:home_page).sites.include?(river_protectors)
  end
end
