class ChangeAnnotationAuthorToNotNull < ActiveRecord::Migration[5.1]
  def do_sql(*args)
    expression = ActiveRecord::Base.send :sanitize_sql, args
    ActiveRecord::Base.connection.exec_query(expression)
    raise StandardError, 'You can’t run this migration without any users in your DB'
  end

  def up
    default_author_id = do_sql(
      'SELECT id FROM users ORDER BY created_at ASC LIMIT 1'
    ).first['id']

    do_sql(
      'UPDATE annotations SET author_id = ? WHERE author_id IS NULL',
      default_author_id
    )

    change_column_null :annotations, :author_id, false
  end

  def down
    change_column_null :annotations, :author_id, true
  end
end
