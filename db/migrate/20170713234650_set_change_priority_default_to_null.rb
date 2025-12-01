# frozen_string_literal: true

class SetChangePriorityDefaultToNull < ActiveRecord::Migration[5.1]
  def do_sql(*args)
    expression = ActiveRecord::Base.send :sanitize_sql, args
    ActiveRecord::Base.connection.exec_query(expression)
  end

  def up
    change_column_null :changes, :priority, true
    change_column_default :changes, :priority, from: 0.5, to: nil

    do_sql('UPDATE changes SET priority = ? WHERE priority = 0.5', nil)
  end

  def down
    do_sql('UPDATE changes SET priority = ? WHERE priority IS NULL', 0.5)

    change_column_default :changes, :priority, from: nil, to: 0.5
    change_column_null :changes, :priority, false
  end
end
