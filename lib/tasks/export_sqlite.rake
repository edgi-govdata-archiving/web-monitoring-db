SQLITE_CONVERSIONS = {
  'TrueClass' => ->(_value) { 1 },
  'FalseClass' => ->(_value) { 0 },
  'ActiveSupport::TimeWithZone' => ->(value) { value.utc.iso8601(3) },
  'Hash' => lambda(&:to_json)
}.freeze

def sqlite_convert(ruby_value)
  converter = SQLITE_CONVERSIONS.fetch(ruby_value.class.to_s, nil)
  converter ? converter.call(ruby_value) : ruby_value
end

def write_rows_sqlite(db, table, records, fields: nil)
  fields ||= records.try(:column_names) || records.first.class.column_names
  sql_fields = fields.map { |n| "'#{SQLite3::Database.quote(n.to_s)}'" }
  placeholders = fields.map { '?' }

  sql = "INSERT OR IGNORE INTO #{table} (#{sql_fields.join(',')}) VALUES (#{placeholders.join(',')})"
  count = 0
  records.each do |record|
    values = record.is_a?(Array) ? record : fields.map {|field| sqlite_convert(record[field]) }
    db.execute(sql, values)
    count += 1
  end

  count
end

def write_row_sqlite(db, table, record)
  write_rows_sqlite(db, table, [record])
end

def estimate_row_count(model)
  model.connection
    .query("SELECT reltuples::bigint AS estimate FROM pg_class WHERE oid = 'public.#{model.table_name}'::regclass;")
    .first
    .first
end

create_schema_sql = <<-ARCHIVE_SCHEMA
  -- Store UUIDs as strings. This is a good writeup of pros/cons:
  --   https://vespa-mrs.github.io/vespa.io/development/project_dev/database/DatabaseUuidEfficiency.html
  -- There is also a first-party extension: https://sqlite.org/src/file/ext/misc/uuid.c
  -- But this DB is for archival, so it's probably better to stick to basic types.
  -- Store date-times as strings. SQLite time operations can transparently handle ISO 8601 strings (no offset, it
  --   assumes UTC) or numbers, but numbers are complicated: in some cases it just defaults to Julian day, in others
  --   it uses heuristics to choose whether to interpret the value as Julian days or Unix Epoch seconds. Math and
  --   conversion also ignore leap seconds and other time complexities. For archival, ISO 8601 strings are clearer
  --   and more portable, even if less efficient for storage.

  -- Consider doing a test run with this on and turning off for final export.
  PRAGMA foreign_keys = OFF;

  CREATE TABLE IF NOT EXISTS annotations (
      uuid TEXT NOT NULL PRIMARY KEY,
      change_uuid TEXT NOT NULL,
      annotation TEXT NOT NULL,
      created_at DATETIME NOT NULL,
      updated_at DATETIME NOT NULL,

      FOREIGN KEY(change_uuid) REFERENCES changes(uuid)
  );

  CREATE TABLE IF NOT EXISTS changes (
      uuid TEXT NOT NULL PRIMARY KEY,
      uuid_from TEXT NOT NULL,
      uuid_to TEXT NOT NULL,
      priority REAL,
      current_annotation TEXT,
      created_at DATETIME NOT NULL,
      updated_at DATETIME NOT NULL,
      significance REAL,

      UNIQUE(uuid_to, uuid_from),

      FOREIGN KEY(uuid_from) REFERENCES versions(uuid),
      FOREIGN KEY(uuid_to) REFERENCES versions(uuid)
  );

  CREATE TABLE IF NOT EXISTS maintainers (
      uuid TEXT NOT NULL PRIMARY KEY,
      name TEXT NOT NULL,
      parent_uuid TEXT,
      created_at DATETIME NOT NULL,
      updated_at DATETIME NOT NULL,

      UNIQUE(name)
  );

  CREATE TABLE IF NOT EXISTS maintainerships (
      maintainer_uuid TEXT NOT NULL,
      page_uuid TEXT NOT NULL,
      created_at DATETIME NOT NULL,

      UNIQUE(maintainer_uuid, page_uuid),

      FOREIGN KEY(maintainer_uuid) REFERENCES maintainers(uuid),
      FOREIGN KEY(page_uuid) REFERENCES pages(uuid)
  );

  CREATE TABLE IF NOT EXISTS merged_pages (
      uuid TEXT NOT NULL PRIMARY KEY,
      target_uuid TEXT NOT NULL,
      audit_data TEXT,

      FOREIGN KEY(target_uuid) REFERENCES pages(uuid)
  );

  CREATE TABLE IF NOT EXISTS page_urls (
      uuid TEXT NOT NULL PRIMARY KEY,
      page_uuid TEXT NOT NULL,
      url TEXT NOT NULL,
      url_key TEXT NOT NULL,
      from_time DATETIME  NOT NULL,
      to_time DATETIME NOT NULL,
      notes TEXT,
      created_at DATETIME NOT NULL,
      updated_at DATETIME NOT NULL,

      UNIQUE(page_uuid, url, from_time, to_time),

      FOREIGN KEY(page_uuid) REFERENCES pages(uuid)
  );

  CREATE TABLE IF NOT EXISTS pages (
      uuid TEXT NOT NULL PRIMARY KEY,
      url TEXT NOT NULL,
      title TEXT,
      created_at DATETIME NOT NULL,
      updated_at DATETIME NOT NULL,
      url_key TEXT,
      active BOOLEAN,
      status INTEGER
  );

  CREATE TABLE IF NOT EXISTS taggings (
      taggable_uuid TEXT NOT NULL,
      taggable_type TEXT,
      tag_uuid TEXT NOT NULL,
      created_at DATETIME NOT NULL,

      UNIQUE(taggable_uuid, tag_uuid),

      FOREIGN KEY(tag_uuid) REFERENCES tags(uuid)
  );

  CREATE TABLE IF NOT EXISTS tags (
      uuid TEXT NOT NULL PRIMARY KEY,
      name TEXT NOT NULL,
      created_at DATETIME NOT NULL,
      updated_at DATETIME NOT NULL,

      UNIQUE(name)
  );

  CREATE TABLE IF NOT EXISTS versions (
      uuid TEXT NOT NULL PRIMARY KEY,
      page_uuid TEXT,
      capture_time DATETIME NOT NULL,
      body_url TEXT,
      body_hash TEXT,
      source_type TEXT,
      source_metadata TEXT,
      created_at DATETIME NOT NULL,
      updated_at DATETIME NOT NULL,
      title TEXT,
      url TEXT,
      different BOOLEAN,
      status INTEGER,
      content_length INTEGER,
      media_type TEXT,
      headers TEXT,

      FOREIGN KEY(page_uuid) REFERENCES pages(uuid)
  );
ARCHIVE_SCHEMA

add_version_indexes_schema_sql = <<-ARCHIVE_SCHEMA
  CREATE INDEX IF NOT EXISTS versions_capture_time_uuid ON versions (capture_time, uuid);
ARCHIVE_SCHEMA

desc 'Export a copy of the DB as SQLite designed for public archiving'
task :export_sqlite, [:export_path] => [:environment] do |_t, args|
  require 'sqlite3'

  export_path = args[:export_path] || 'archive.sqlite3'

  puts "Writing database to file '#{export_path}'..."
  SQLite3::Database.new export_path do |db|
    puts 'Initializing database...'
    db.transaction { db.execute_batch2(create_schema_sql) }

    puts 'Writing page records...'
    db.transaction do
      write_rows_sqlite(db, 'pages', Page.all)
      write_rows_sqlite(db, 'page_urls', PageUrl.all)
      write_rows_sqlite(db, 'merged_pages', MergedPage.all)
    end

    puts 'Writing tags...'
    db.transaction do
      write_rows_sqlite(db, 'tags', Tag.all)
      write_rows_sqlite(db, 'taggings', Tagging.all)
    end

    puts 'Writing maintainers...'
    db.transaction do
      write_rows_sqlite(db, 'maintainers', Maintainer.all)
      write_rows_sqlite(db, 'maintainerships', Maintainership.all)
    end

    puts 'Writing versions...'
    # Ideally we'd use `Version.in_batches(...)` for this, but it's just really hard to get reasonable performance out
    # of it. You need a batch size that nears your memory limits but reliably never goes over, and you spend a lot of
    # time marshalling data on either end. It also creates disk access patterns in Postgres that don't work great on
    # AWS's I/O constrained disks. On the other hand, `COPY` works really well. It's just a lot more complicated.
    # In a perfect world, we'd abstract this a bit and use it for every table, but it's not worth the effort right now.
    transaction_size = 10_000
    written_count = 0
    expected_count = estimate_row_count(Version)
    version_fields = Version.column_names
    db.transaction
    begin
      Version.connection.send(:with_raw_connection) do |conn|
        copy_decoder = PG::TextDecoder::CopyRow.new
        conn.copy_data('COPY versions TO STDOUT (FORMAT text)', copy_decoder) do
          while row = conn.get_copy_data # rubocop:disable Lint/AssignmentInCondition
            # Value formatting is different here than with model objects; we're dealing with Postgres's string
            # representation for pretty much everything.
            values = []
            row.each_with_index do |value, index|
              values << case version_fields[index]
                        when /_(at|time)$/
                          value&.sub(/(:\d\d\.\d\d\d).*/, '\1')
                        when 'different'
                          value == 't' ? 1 : 0
                        else
                          value
                        end
            end
            write_rows_sqlite(db, 'versions', [values], fields: version_fields)
            written_count += 1
            next unless written_count % transaction_size == 0

            db.commit
            db.transaction

            percentage = 100.0 * written_count / expected_count
            $stdout.write "\r  Committed #{written_count} records (#{percentage.round(2)}%)   "
          end
        end
      end
      db.commit
      # Write out a final 100%, since the previously written values are based on an estimated total.
      puts "\r  Committed #{written_count} records (100%)   "
    rescue StandardError => error
      db.rollback
      puts ''
      raise error
    end

    puts 'Indexing versions...'
    db.transaction { db.execute_batch2(add_version_indexes_schema_sql) }

    puts 'Writing significant changes and annotations...'
    Change.where(significance: 0.5...).each do |change|
      write_row_sqlite(db, 'changes', change)
      write_rows_sqlite(db, 'annotations', change.annotations, fields: Annotation.column_names.filter {|n| n != 'author_id'})
    end
  end

  puts 'Done!'
end
