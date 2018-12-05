require 'test_helper'

class ChangeTest < ActiveSupport::TestCase
  test 'between should find a change based on two versions' do
    from_version = versions(:page1_v1)
    to_version = versions(:page1_v2)
    found = Change.between(from: from_version, to: to_version)

    assert(found.is_a?(Change), 'It did not return a Change')
    assert(found.persisted?, 'The returned change did not already exist')
    assert_equal(from_version.id, found.from_version.id, 'It has the wrong `from_version`')
    assert_equal(to_version.id, found.version.id, 'It has the wrong `version`')
  end

  test 'between should find a change based on two IDs' do
    from_version = versions(:page1_v1)
    to_version = versions(:page1_v2)
    found = Change.between(from: from_version.id, to: to_version.id)

    assert(found.is_a?(Change), 'It did not return a Change')
    assert(found.persisted?, 'The returned change did not already exist')
    assert_equal(from_version.id, found.from_version.id, 'It has the wrong `from_version`')
    assert_equal(to_version.id, found.version.id, 'It has the wrong `version`')
  end

  test 'between should instantiate a change based on two versions if a matching change does not already exist' do
    from_version = versions(:page1_v3)
    to_version = versions(:page1_v4)
    found = Change.between(from: from_version, to: to_version)

    assert(found.is_a?(Change), 'It did not return a Change')
    assert_not(found.persisted?, 'The returned change did not already exist')
    assert_equal(from_version.id, found.from_version.id, 'It has the wrong `from_version`')
    assert_equal(to_version.id, found.version.id, 'It has the wrong `version`')
  end

  test 'between should instantiate a change based on two IDs if a matching change does not exist' do
    from_version = versions(:page1_v3)
    to_version = versions(:page1_v4)
    found = Change.between(from: from_version.id, to: to_version.id)

    assert(found.is_a?(Change), 'It did not return a Change')
    assert_not(found.persisted?, 'The returned change did not already exist')
    assert_equal(from_version.id, found.from_version.id, 'It has the wrong `from_version`')
    assert_equal(to_version.id, found.version.id, 'It has the wrong `version`')
  end

  test 'between should create and persist a change if requested' do
    from_version = versions(:page1_v3)
    to_version = versions(:page1_v4)
    found = Change.between(from: from_version, to: to_version, create: :create)

    assert(found.is_a?(Change), 'It did not return a Change')
    assert(found.persisted?, 'The returned change was not persisted')
    assert_equal(from_version.id, found.from_version.id, 'It has the wrong `from_version`')
    assert_equal(to_version.id, found.version.id, 'It has the wrong `version`')
  end

  test 'find_by_api_id should work with IDs like `{from_id}..{to_id}`' do
    from_version = versions(:page1_v1)
    to_version = versions(:page1_v2)
    found = Change.find_by_api_id("#{from_version.id}..#{to_version.id}")

    assert(found.is_a?(Change), 'It did not return a Change')
    assert_equal(from_version.id, found.from_version.id, 'It has the wrong `from_version`')
    assert_equal(to_version.id, found.version.id, 'It has the wrong `version`')
  end

  test 'find_by_api_id should work with actual change IDs' do
    change = changes(:page1_change_1_2)
    found = Change.find_by_api_id(change.id)

    assert(found.is_a?(Change), 'It did not return a Change')
    assert_equal(change.from_version.id, found.from_version.id, 'It has the wrong `from_version`')
    assert_equal(change.version.id, found.version.id, 'It has the wrong `version`')
  end

  test 'annotate should create an annotation' do
    change = versions(:page2_v3).ensure_change_from_previous
    change.annotate({ test_field: 'test_value' }, users(:alice))

    assert_equal 1, change.annotations.length, 'The wrong number of annotations were added!'
  end

  test 'adding an annotation should update current_annotation' do
    change = versions(:page2_v3).ensure_change_from_previous
    change.annotate({ test_field: 'test_value' }, users(:alice))

    assert_equal({ 'test_field' => 'test_value' }, change.current_annotation)
  end

  test 'annotations should merge by including omitted properties and removing null properties' do
    change = versions(:page2_v3).ensure_change_from_previous

    change.annotate({ one: 'a', two: 'b', three: 'c' }, users(:admin_user))
    change.annotate({ one: 'new!', three: nil }, users(:alice))

    assert_equal({ 'one' => 'new!', 'two' => 'b' }, change.current_annotation)
  end

  test 'annotating a new change should persist it' do
    change = versions(:page2_v3).ensure_change_from_previous
    assert_not change.persisted?, 'The change we are testing was not newly created'

    change.annotate({ test_field: 'test_value' }, users(:alice))
    assert change.persisted?, 'The change was not persisted'
  end

  test 'subsequent annotations by the same user should replace the existing annotation' do
    change = versions(:page2_v3).ensure_change_from_previous

    change.annotate({ one: 'a', two: 'b', three: 'c' }, users(:alice))
    change.annotate({ one: 'new!', three: nil }, users(:alice))

    assert_equal 1, change.annotations.count, 'Multiple annotations were made'
    # the second annotation replaces the first instead of combining with it
    assert_equal({ 'one' => 'new!' }, change.current_annotation, 'Current annotation was not replaced')
  end

  test 'subsequent annotations with different users should create new annotations' do
    change = versions(:page2_v3).ensure_change_from_previous

    change.annotate({ one: 'a', two: 'b', three: 'c' }, users(:alice))
    change.annotate({ one: 'new!', three: nil }, users(:admin_user))

    assert_equal 2, change.annotations.count, 'The wrong number of annotations were made'
  end

  test 'annotating with `priority` should update #priority' do
    change = versions(:page2_v3).ensure_change_from_previous
    change.annotate({ priority: 1 }, users(:alice))
    assert_equal(1, change.priority, '#priority was not updated')
  end

  test 'annotating with `significance` should update #significance' do
    change = versions(:page2_v3).ensure_change_from_previous
    change.annotate({ significance: 1 }, users(:alice))
    assert_equal(1, change.significance, '#significance was not updated')
  end
end
