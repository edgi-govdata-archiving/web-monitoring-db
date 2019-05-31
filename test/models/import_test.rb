require 'test_helper'

class ImportTest < ActiveSupport::TestCase
  test 'import models can be created with data and retrieve it' do
    data = 'TEST DATA'
    import = Import.create_with_data({ user: users(:alice) }, data)
    assert(import.present?, 'Import instance did not have a file attribute')
    assert_equal(data, import.load_data, 'Retrieved data did not match stored data')
  end

  test 'persists ndjson-ified logs to a file' do
    import = Import.create_with_data({ user: users(:alice) }, 'TEST DATA')

    FIRST_LOG_LINE = 'This is a log'.freeze
    SECOND_LOG_LINE = 'Another log'.freeze
    import.add_log FIRST_LOG_LINE
    import.add_log SECOND_LOG_LINE

    import.save

    assert_equal(<<~LOGS.strip, import.load_logs, 'log file should contain ndjson-ified logs')
      "#{FIRST_LOG_LINE}"
      "#{SECOND_LOG_LINE}"
    LOGS

    THIRD_LOG_LINE = 'this is a third line'.freeze
    import.add_log THIRD_LOG_LINE

    import.save

    assert_equal(<<~LOGS.strip, import.load_logs, 'log file should contain newly added ndjson-ified logs')
      "#{FIRST_LOG_LINE}"
      "#{SECOND_LOG_LINE}"
      "#{THIRD_LOG_LINE}"
    LOGS
  end
end
