require 'test_helper'

class Differ::SimpleDiffTest < ActiveSupport::TestCase
  test 'it gets the diff for a change from a URL' do
    change = changes(:page1_change_1_2)

    expected_request = stub_request(:any, 'http://testdiff.com')
      .with(query: {
        'a' => change.from_version.body_url,
        'a_hash' => change.from_version.body_hash,
        'b' => change.version.body_url,
        'b_hash' => change.version.body_hash
      })
      .to_return(body: 'DIFF!', status: 200)

    differ = Differ::SimpleDiff.new('http://testdiff.com')
    diff = differ.diff(change)

    assert_requested expected_request
    assert_equal 'DIFF!', diff
  end

  test 'it gets the diff for a change that has a network error' do
    change = changes(:page1_change_5_network_error)

    expected_request = stub_request(:any, 'http://testdiff.com')
      .with(query: {
        'a' => change.from_version.body_url,
        'a_hash' => change.from_version.body_hash,
        'b' => Rails.application.routes.url_helpers.raw_api_v0_version_url(change.version),
        'b_hash' => ''
      })
      .to_return(body: 'DIFF!', status: 200)

    differ = Differ::SimpleDiff.new('http://testdiff.com')
    diff = differ.diff(change)

    assert_requested expected_request
    assert_equal 'DIFF!', diff
  end

  test 'it sends any additional options as query parameters' do
    change = changes(:page1_change_1_2)

    expected_request = stub_request(:any, 'http://testdiff.com')
      .with(query: {
        'a' => change.from_version.body_url,
        'a_hash' => change.from_version.body_hash,
        'b' => change.version.body_url,
        'b_hash' => change.version.body_hash,
        'something' => 'funky'
      })

    differ = Differ::SimpleDiff.new('http://testdiff.com')
    differ.diff(change, something: 'funky')

    assert_requested expected_request
  end

  test 'it parses the result as JSON based on content-type' do
    change = changes(:page1_change_1_2)

    stub_request(:any, 'http://testdiff.com')
      .with(query: {
        'a' => change.from_version.body_url,
        'a_hash' => change.from_version.body_hash,
        'b' => change.version.body_url,
        'b_hash' => change.version.body_hash
      })
      .to_return(
        body: '{"key": "value"}',
        status: 200,
        headers: { 'Content-Type' => 'application/json' }
      )

    differ = Differ::SimpleDiff.new('http://testdiff.com')
    result = differ.diff(change)

    assert_equal({ 'key' => 'value' }, result)
  end

  test 'it retries requests to avoid intermittent failures' do
    change = changes(:page1_change_1_2)

    stub_request(:any, 'http://testdiff.com')
      .with(query: {
        'a' => change.from_version.body_url,
        'a_hash' => change.from_version.body_hash,
        'b' => change.version.body_url,
        'b_hash' => change.version.body_hash
      })
      .to_timeout
      .to_return(body: 'Ugh!', status: 500)
      .to_return(body: 'DIFF!', status: 200)

    differ = Differ::SimpleDiff.new('http://testdiff.com')
    diff = differ.diff(change)
    assert_equal('DIFF!', diff)
  end
end
