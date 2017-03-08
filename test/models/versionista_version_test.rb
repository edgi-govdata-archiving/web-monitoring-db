require 'test_helper'

class VersionistaVersionTest < ActiveSupport::TestCase
  test "should have a correct versionista url" do
    version = VersionistaVersion.new(
      page: versionista_pages(:one),
      diff_with_previous_url: 'https://versionista.com/74275/6210946/10038376:0/',
      diff_with_first_url: 'https://versionista.com/74275/6210946/10038376:9446087/',
      diff_length: 18489,
      diff_hash: 'a000e229ab708657cdbfef5dd105b7cecd706d0c54cab358d33775e198adf9e6',
      versionista_version_id: 5539,
      relevant: true)

    assert_equal 'https://versionista.com/74275/6210946/10038376/', version.view_url
  end

  test "individual annotations should get some metadata" do
    version = VersionistaVersion.new
    version.annotate({test_field: 'test_value'})

    assert_equal 1, version.annotations.length, "The wrong number of annotations were added!"

    annotation = version.annotations[0]
    assert_match /^\h+-\h+-\h+-\h+-\h+$/, annotation['id'], "Annotations should have an ID that is a UUID"
    DateTime.parse(annotation['created_at'])
    assert_equal version.id, annotation['version'], "The annotation's version should match the ID of the version it annotates"
  end

  test "adding an annotation should update current_annotation" do
    version = VersionistaVersion.new
    version.annotate({test_field: 'test_value'})

    assert_equal({'test_field' => 'test_value'}, version.current_annotation)
  end

  test "annotations should merge by including omitted properties and removing null properties" do
    version = VersionistaVersion.new

    version.annotate({one: 'a', two: 'b', three: 'c'})
    version.annotate({one: 'new!', three: nil})

    assert_equal({'one' => 'new!', 'two' => 'b'}, version.current_annotation)
  end
end
