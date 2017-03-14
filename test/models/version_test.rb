require 'test_helper'

class VersionTest < ActiveSupport::TestCase
  test "previous should get the previous version" do
    previous = versions(:page2_v2).previous
    assert_equal versions(:page2_v1), previous, "Previous returned the wrong version"
  end

  test "change from previous should always return a change object (even if unpersisted)" do
    change = versions(:page2_v2).change_from_previous
    assert_not_nil change
  end
end
