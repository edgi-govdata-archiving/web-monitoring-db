require 'test_helper'

class Differ::DifferTest < ActiveSupport::TestCase
  setup do
    @original_default_differ = Differ.for_type(nil)
  end

  teardown do
    Differ.register(nil, @original_default_differ)
  end

  test 'it creates a new default differ if an unknown type is requested' do
    Differ.register(nil, 'http://testdiff.com')
    change = changes(:page1_change_1_2)

    expected_request = stub_request(:any, 'http://testdiff.com/unknown_type')
      .with(query: {
        'a' => change.from_version.uri,
        'a_hash' => change.from_version.version_hash,
        'b' => change.version.uri,
        'b_hash' => change.version.version_hash
      })
      .to_return(body: 'DIFF!', status: 200)

    diff = Differ.for_type('unknown_type').diff(change)
    assert_requested expected_request
    assert_equal 'DIFF!', diff
  end
end
