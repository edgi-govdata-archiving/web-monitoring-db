require 'test_helper'
require 'minitest/mock'

class AnalyzeChangeJobTest < ActiveJob::TestCase
  test 'produces change with annotations' do
    change = changes(:page1_change_1_2)

    differ_mock = Minitest::Mock.new(Differ)
    def differ_mock.diff(_change)
      {
        'diff' => [
          [1, 'addition'],
          [-1, 'subtraction']
        ]
      }
    end

    Differ.stub(:for_type!, differ_mock) do
      AnalyzeChangeJob.perform_now(change.version, change.from_version)
    end

    new_change = Change.last
    assert_equal new_change.version, change.version
    assert_equal new_change.from_version, change.from_version

    new_annotation = new_change.current_annotation
    assert_equal new_annotation['text_diff_count'], 2
    assert_equal new_annotation['source_diff_count'], 2
    assert_equal new_annotation['links_diff_count'], 2
  end
end
