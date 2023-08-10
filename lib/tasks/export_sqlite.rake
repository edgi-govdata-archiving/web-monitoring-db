SQLITE_CONVERSIONS = {
  'TrueClass' => ->(_value) { 1 },
  'FalseClass' => ->(_value) { 0 },
  'ActiveSupport::TimeWithZone' => ->(value) { value.utc.iso8601(3) },
  'Hash' => ->(value) { value.to_json }
}.freeze

def sqlite_convert(ruby_value)
  converter = SQLITE_CONVERSIONS.fetch(ruby_value.class.to_s, nil)
  converter ? converter.call(ruby_value) : ruby_value
end

def write_rows_sqlite(db, table, data, fields)
  names = []
  values = []
  fields.each do |field|
    names << "'#{SQLite3::Database.quote(field.to_s)}'"
    values << sqlite_convert(data.try!(field))
  end
  placeholders = names.collect {'?'}

  db.execute(
    "INSERT INTO #{table} (#{names.join(',')}) VALUES (#{placeholders.join(',')})",
    values
  )
end

create_schema_sql = <<-ARCHIVE_SCHEMA
  -- Store UUIDs as strings. This is a good writeup of pros/cons:
  --   https://vespa-mrs.github.io/vespa.io/development/project_dev/database/DatabaseUuidEfficiency.html
  -- There is also a first-party extension: https://sqlite.org/src/file/ext/misc/uuid.c
  -- But this DB is for archival, so it's probably better to stick to basic types.

  -- Consider doing a test run with this on and turning off for final export.
  PRAGMA foreign_keys = ON;

  CREATE TABLE annotations (
      uuid TEXT NOT NULL PRIMARY KEY,
      change_uuid TEXT NOT NULL,
      annotation TEXT NOT NULL,
      created_at DATETIME NOT NULL,
      updated_at DATETIME NOT NULL,

      FOREIGN KEY(change_uuid) REFERENCES changes(uuid)
  );

  CREATE TABLE changes (
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

  CREATE TABLE maintainers (
      uuid TEXT NOT NULL PRIMARY KEY,
      name TEXT NOT NULL,
      parent_uuid TEXT,
      created_at DATETIME NOT NULL,
      updated_at DATETIME NOT NULL,

      UNIQUE(name)
  );

  CREATE TABLE maintainerships (
      maintainer_uuid TEXT NOT NULL,
      page_uuid TEXT NOT NULL,
      created_at DATETIME NOT NULL,

      UNIQUE(maintainer_uuid, page_uuid),

      FOREIGN KEY(maintainer_uuid) REFERENCES maintainers(uuid),
      FOREIGN KEY(page_uuid) REFERENCES pages(uuid)
  );

  CREATE TABLE merged_pages (
      uuid TEXT NOT NULL PRIMARY KEY,
      target_uuid TEXT NOT NULL,
      audit_data TEXT,

      FOREIGN KEY(target_uuid) REFERENCES pages(uuid)
  );

  CREATE TABLE page_urls (
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

  CREATE TABLE pages (
      uuid TEXT NOT NULL PRIMARY KEY,
      url TEXT NOT NULL,
      title TEXT,
      created_at DATETIME NOT NULL,
      updated_at DATETIME NOT NULL,
      url_key TEXT,
      active BOOLEAN,
      status INTEGER
  );

  CREATE TABLE taggings (
      taggable_uuid TEXT NOT NULL,
      taggable_type TEXT,
      tag_uuid TEXT NOT NULL,
      created_at DATETIME NOT NULL,

      UNIQUE(taggable_uuid, tag_uuid),

      FOREIGN KEY(tag_uuid) REFERENCES tags(uuid)
  );

  CREATE TABLE tags (
      uuid TEXT NOT NULL PRIMARY KEY,
      name TEXT NOT NULL,
      created_at DATETIME NOT NULL,
      updated_at DATETIME NOT NULL,

      UNIQUE(name)
  );

  CREATE TABLE versions (
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
      status INTEGER,
      content_length INTEGER,
      media_type TEXT,
      headers TEXT,

      FOREIGN KEY(page_uuid) REFERENCES pages(uuid)
  );

  CREATE INDEX versions_capture_time_uuid ON versions (capture_time, uuid);
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
      Page.all.each do |page|
        write_rows_sqlite(db, 'pages', page, [:uuid, :url, :url_key, :title, :active, :status, :created_at, :updated_at])
      end

      PageUrl.all.each do |page_url|
        write_rows_sqlite(db, 'page_urls', page_url, [
                            :uuid,
                            :page_uuid,
                            :url,
                            :url_key,
                            :from_time,
                            :to_time,
                            :notes,
                            :created_at,
                            :updated_at
                          ])
      end

      MergedPage.all.each do |page|
        write_rows_sqlite(db, 'merged_pages', page, [:uuid, :target_uuid, :audit_data])
      end
    end

    puts 'Writing tags...'
    db.transaction do
      Tag.all.each do |tag|
        write_rows_sqlite(db, 'tags', tag, [
                            :uuid,
                            :name,
                            :created_at,
                            :updated_at
                          ])
      end

      Tagging.all.each do |tagging|
        write_rows_sqlite(db, 'taggings', tagging, [
                            :taggable_uuid,
                            :taggable_type,
                            :tag_uuid,
                            :created_at
                          ])
      end
    end

    puts 'Writing maintainers...'
    db.transaction do
      Maintainer.all.each do |tag|
        write_rows_sqlite(db, 'maintainers', tag, [
                            :uuid,
                            :name,
                            :parent_uuid,
                            :created_at,
                            :updated_at
                          ])
      end

      Maintainership.all.each do |maintainership|
        write_rows_sqlite(db, 'maintainerships', maintainership, [
                            :maintainer_uuid,
                            :page_uuid,
                            :created_at
                          ])
      end
    end

    puts 'Writing versions...'
    DataHelpers.iterate_batches(Version.all, by: [:capture_time, :uuid], batch_size: 10_000) do |versions|
      db.transaction do
        versions.each do |version|
          write_rows_sqlite(db, 'versions', version, [
                              :uuid,
                              :page_uuid,
                              :capture_time,
                              :body_url,
                              :body_hash,
                              :source_type,
                              :source_metadata,
                              :created_at,
                              :updated_at,
                              :title,
                              :url,
                              :status,
                              :content_length,
                              :media_type,
                              :headers
                            ])
        end
      end
    end

    # TODO: Changes and annotations are complicated:
    # - No sequential queryable field like Versions
    # - Questionable value in the first place (we probably just want the human-written ones)
    # puts "Writing changes..."
    # puts "Writing annotations..."
  end

  puts 'Done!'
end
