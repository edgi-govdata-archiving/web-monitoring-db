require 'test_helper'

class ChangeTest < ActiveSupport::TestCase
  test "annotate should create an annotation" do
    change = versions(:page2_v2).change_from_previous
    change.annotate({test_field: 'test_value'})

    assert_equal 1, change.annotations.length, "The wrong number of annotations were added!"
  end

  test "adding an annotation should update current_annotation" do
    change = versions(:page2_v2).change_from_previous
    change.annotate({test_field: 'test_value'})

    assert_equal({'test_field' => 'test_value'}, change.current_annotation)
  end

  test "annotations should merge by including omitted properties and removing null properties" do
    change = versions(:page2_v2).change_from_previous

    change.annotate({one: 'a', two: 'b', three: 'c'})
    change.annotate({one: 'new!', three: nil})

    assert_equal({'one' => 'new!', 'two' => 'b'}, change.current_annotation)
  end

  test "annotating a new change should persist it" do
    change = versions(:page2_v2).change_from_previous
    assert_not change.persisted?, "The change we are testing was not newly created"

    change.annotate({test_field: 'test_value'})
    assert change.persisted?, "The change was not persisted"
  end
end
