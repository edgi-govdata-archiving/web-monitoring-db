# Store and retrieve files from the local filesystem.
class FileStorage::LocalFile
  # Creates a new LocalFile store.
  # +path+ Specifies the directory in which to store files. If not specified,
  #        files will be stored in a random-named temporary directory.
  # +tag+  Controls naming of temporary directories. If specified, temporary
  #        directory names will be prefixed with this.
  def initialize(path: nil, tag: 'storage')
    @directory = path
    @tag = tag
    @ensured = false
  end

  def directory
    @directory ||= Dir.mktmpdir "web-monitoring-db--#{@tag}"
  end

  def get_file(path)
    File.read(full_path(path))
  end

  def save_file(path, content)
    ensure_directory
    File.write(full_path(path), content)
  end

  def url_for_file(path)
    "file://#{full_path(path)}"
  end

  def contains_url?(url_string)
    if url_string.starts_with? 'file://'
      path = url_string[7..-1]
      File.exist? path
    else
      false
    end
  end

  private

  def full_path(path)
    File.join(directory, path)
  end

  def ensure_directory
    unless @ensured
      @ensured = true
      FileUtils.mkdir_p directory
    end
    directory
  end
end
