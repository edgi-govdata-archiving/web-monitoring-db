# Convert Ruby types to SQLite. Used when writing Active Record models to SQLite.
SQLITE_CONVERSIONS = {
  'TrueClass' => ->(_value) { 1 },
  'FalseClass' => ->(_value) { 0 },
  'ActiveSupport::TimeWithZone' => ->(value) { value.utc.iso8601(3) },
  'Hash' => lambda(&:to_json)
}.freeze

# Convert Postgres types' "text" representation to SQLite. This is used in COPY operations, while the above
# SQLITE_CONVERSIONS is used in normal ActiveRecord-based operations.
# If a type is not listed here, it will be passed to Postgres to parse as a string.
PG_TEXT_SQLITE_CONVERSIONS = {
  boolean: lambda { |value|
    if value == 't'
      1
    elsif value == 'f'
      0
    end
  },
  # Truncate seconds to 3 decimal points.
  timestamp: ->(value) { value&.sub(/(:\d\d\.\d\d\d)\d*/, '\1') }
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

##
# Iterate through the rows returned by the SQL `COPY` command.
# The +sql+ string is expected to be in the form `COPY <table> [columns?] TO STDOUT (FORMAT text[, other options])`
# This will yield each row of copy output as an array of column values, each of which is a string or nil.
def copy_each(connection, sql)
  connection.send(:with_raw_connection) do |pg_connection|
    copy_decoder = PG::TextDecoder::CopyRow.new
    pg_connection.copy_data(sql, copy_decoder) do
      while row = pg_connection.get_copy_data # rubocop:disable Lint/AssignmentInCondition
        yield(row)
      end
    end
  end
end

##
# Copy a model's entire table from Postgres to SQLite. This is much faster *and* lower memory than iterating using
# Active Record's `#in_batches` method when you have to write out an especially large number of rows, although it can't
# lean on Active Record's parsing system for handling different column types. The type handling here is very simple.
# Yields the number of rows written after each transaction completes.
# Returns the total number of rows written.
def copy_table(db, model, fields: nil, transaction_size: 10_000) # rubocop:disable Metrics/CyclomaticComplexity
  fields ||= model.column_names
  conversions = model.columns.filter { |c| fields.include?(c.name) }.map do |column|
    type = column.sql_type
    type = :timestamp if type.start_with?('timestamp')
    PG_TEXT_SQLITE_CONVERSIONS[type.to_sym] || ->(value) { value }
  end

  sql = "INSERT OR IGNORE INTO #{model.table_name}
    (#{fields.map { |n| "'#{SQLite3::Database.quote(n.to_s)}'" }.join(',')})
    VALUES (#{fields.map { '?' }.join(',')})"

  count = 0
  begin
    db.transaction
    copy_each(model.connection, "COPY #{model.table_name} TO STDOUT (FORMAT text)") do |row|
      values = row.map.with_index { |value, index| conversions[index].call(value) }
      db.execute(sql, values)
      count += 1
      next unless count % transaction_size == 0

      db.commit
      yield count if block_given?
      db.transaction
    end
    db.commit
  rescue StandardError => error
    db.rollback
    raise error
  end

  yield count if block_given?
  count
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

  -- No need to enforce these constraints, since we know all our data is already correct in Postgres.
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
    expected_count = estimate_row_count(Version)
    copy_table(db, Version) do |count|
      percentage = 100.0 * count / expected_count
      $stdout.write "\r  Committed #{count} records (#{percentage.round(2)}%)   "
    end
    puts ''

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
