module FileStorage
  # Store and retrieve files from the local filesystem.
  class LocalFile
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
      File.read(normalize_full_path(path))
    end

    def save_file(path, content, _options = nil)
      ensure_directory
      File.open(full_path(path), 'wb') do |file|
        content_string = content.try(:read) || content
        file.write(content_string)
      end
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

    # Normalize a file URI or path to an absolute path to the file.
    # If the path specifies a directory outside this storage area, this raises
    # ArgumentError.
    def normalize_full_path(path)
      # If it's a file URL, extract the path
      path = path[7..-1] if path.starts_with? 'file://'

      # If it's absolute, make sure it's in this storage's directory
      if path.starts_with?('/')
        unless path.starts_with?(File.join(directory, ''))
          # FIXME: raise a more specific error type!
          raise ArgumentError, "The path '#{path}' does not belong to this storage object"
        end

        path
      else
        full_path(path)
      end
    end

    def ensure_directory
      unless @ensured
        @ensured = true
        FileUtils.mkdir_p directory
      end
      directory
    end
  end
end
