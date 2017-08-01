require 'test_helper'

class ImportTest < ActiveSupport::TestCase
  test 'import models can be created with data and retrieve it' do
    data = 'TEST DATA'
    import = Import.create_with_data({ user: users(:alice) }, data)
    assert(import.present?, 'Import instance did not have a file attribute')
    assert_equal(data, import.load_data, 'Retrieved data did not match stored data')
  end
end
