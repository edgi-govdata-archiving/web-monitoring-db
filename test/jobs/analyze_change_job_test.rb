require 'test_helper'
require 'minitest/mock'

class AnalyzeChangeJobTest < ActiveJob::TestCase
  test 'produces change with annotations' do
    uri = 'https://example.com/about'
    page = Page.create!(url: uri)
    version = Version.create!(capture_time: 1.day.ago, page: page, uri: uri)
    from_version = Version.create!(capture_time: 2.days.ago, page: page, uri: uri)

    differ_mock = Minitest::Mock.new(Differ)
    def differ_mock.diff(_change)
      {
        'version' => '1.2.3+hash',
        'type' => '',
        'change_count' => 2,
        'diff' => [
          [1, 'addition'],
          [-1, 'subtraction']
        ]
      }
    end

    Differ.stub(:for_type!, differ_mock) do
      AnalyzeChangeJob.perform_now(version, from_version)
    end

    new_change = Change.order(created_at: :desc).first
    assert_equal version, new_change.version
    assert_equal from_version, new_change.from_version

    new_annotation = new_change.current_annotation
    assert_equal 2, new_annotation['text_diff_count']
    assert_equal 2, new_annotation['source_diff_count']
    assert_equal 2, new_annotation['links_diff_count']
  end
end
