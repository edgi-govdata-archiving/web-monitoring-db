namespace :data do
  desc 'Clean up and normalize badly formatted Page and Version titles.'
  task :'20181124_normalize_titles', [] => [:environment] do |_t|
    ActiveRecord::Migration.say_with_time('Updating `uri` on versions to new S3 buckets') do
      count = 0
      DataHelpers.with_activerecord_log_level(:error) do
        count += clean_titles(Version)
        count += clean_titles(Page)
      end

      count
    end
  end

  def clean_titles(model_type)
    query = model_type
      .where("title LIKE ' %' OR title LIKE '% ' OR title LIKE '%\n%'")
      .order(created_at: :asc)

    # We're updating what we're querying on, so just repeat until no results.
    updated = 0
    loop do
      values = query.limit(500).collect do |model|
        new_title = model_type.normalize_title_string(model.title)
        "('#{model.uuid}', #{Version.connection.quote(new_title)})"
      end

      updated += values.length
      print "   Updating #{updated} #{model_type.to_s.pluralize} with malformed titles...\r"
      $stdout.flush

      if values.empty?
        # We have to print here to clear the \r at end of the last line
        puts ''
        break
      end

      Version.connection.execute(
        <<-QUERY
          UPDATE
            #{model_type.table_name}
          SET
            title = valueset.title,
            updated_at = #{Version.connection.quote(Time.now)}
          FROM
            (values #{values.join(',')}) as valueset(uuid, title)
          WHERE
            #{model_type.table_name}.uuid = valueset.uuid::uuid
        QUERY
      )
    end

    updated
  end
end
