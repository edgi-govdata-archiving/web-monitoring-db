require 'filemagic'

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
      file_read = File.read(full_path(path))
      # s3 filetype provides this method. We use it as a fallback and for mime_type
      file_read.define_singleton_method(:content_type) do
        FileMagic.new(FileMagic::MAGIC_MIME).file(file_read)
      end
      file_read
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

    def ensure_directory
      unless @ensured
        @ensured = true
        FileUtils.mkdir_p directory
      end
      directory
    end
  end
end
