# From https://github.com/edgi-govdata-archiving/versionista-outputter

require 'zlib'

module VersionistaService
  class PageDiff
    attr_accessor :diff_text

    def length
      if diff_text.nil?
        -1
      else
        diff_text.length
      end
    end

    def hash
      if diff_text.nil?
        -1
      else
        Zlib.crc32(diff_text)
      end
    end
  end
end
