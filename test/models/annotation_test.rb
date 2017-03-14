require 'test_helper'

class AnnotationTest < ActiveSupport::TestCase
  test "annotations must be objects" do
    created_with_nil = Annotation.create(
      change: changes(:page1_change_1_2),
      annotation: nil
    )
    assert_not created_with_nil.valid? 'A nil annotation was valid'

    created_with_an_array = Annotation.create(
      change: changes(:page1_change_1_2),
      annotation: ['a']
    )
    assert_not created_with_an_array.valid? 'An array annotation was valid'

    created_with_an_object = Annotation.create(
      change: changes(:page1_change_1_2),
      annotation: {a: 'b'}
    )
    assert created_with_an_object.valid? 'An object annotation was not valid'
  end
end
