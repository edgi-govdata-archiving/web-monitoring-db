class ChangeAnnotationAuthorToNotNull < ActiveRecord::Migration[5.1]
  def do_sql(*args)
    expression = ActiveRecord::Base.send :sanitize_sql, args
    ActiveRecord::Base.connection.exec_query(expression)
  end

  def up
    default_author = do_sql(
      'SELECT id FROM users ORDER BY created_at ASC LIMIT 1'
    ).first

    if default_author.nil?
      # create a default_author if one doesn't exist
      default_author = User.create(email: 'someone@example.com', password: 'password', confirmed_at: Time.now)
    end

    do_sql(
      'UPDATE annotations SET author_id = ? WHERE author_id IS NULL',
      default_author['id']
    )

    change_column_null :annotations, :author_id, false
  end

  def down
    change_column_null :annotations, :author_id, true
  end
end
