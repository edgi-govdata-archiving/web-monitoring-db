# The Wayback Machine unfortunately has some bugginess around gzip encoding
# that we are working around here.
#
# If you request a memento (e.g. a URL like:
# `http://web.archive.org/web/20181118000000id_/http://epa.gov`) with an
# `Accept-Encoding: gzip` header, Wayback will happily gzip the response body
# and include a `Content-Encoding: gzip` header. However, if the
# original snapshot was gzipped when captured by Wayback, it screws this up --
# the memento response body will be gzipped, but it will include two encoding
# headers: `content-encoding: ` (that's right, it has no value) and then later,
# `Content-Encoding: gzip`. Pretty much any client in this case will obey the
# first one and assume there is no special encoding, so we'll get gzip bytes
# out our end instead of the uncompressed response data we wanted.
#
# This little hack amends HTTParty's Response class to look for this malformed
# header situation, clean up the headers, and decompress the body.
#
# NOTE: you can also avoid this situation by never requesting gzipped responses
# (i.e. not sending `Accept-Encoding` or sending `Accept-Encoding: identity`).
# We are loading lots of data, though, and having it gzipped over the network
# when possible is a huge boon we'd like to keep.
#
# A good test memento for this is: `http://web.archive.org/web/20180101180440id_/http://cwcgom.aoml.noaa.gov/erddap/griddap/miamiacidification.graph`
#
# Also: https://github.com/edgi-govdata-archiving/web-monitoring-db/issues/433
#       https://github.com/edgi-govdata-archiving/web-monitoring-processing/issues/309
module HTTParty
  class Response
    def body
      cleanup_wayback_encoding
      @body
    end

    def headers
      cleanup_wayback_encoding
      @headers
    end

    def cleanup_wayback_encoding
      if @headers['content-encoding'] == ', gzip'
        # This logic is ripped from what HTTParty used to do (it stopped
        # explicitly handling content-encoding since the underlying Net::HTTP
        # module does it already). See: https://github.com/jnunemaker/httparty/commit/6f6bf6b726484eaf50e190769bbe14c9841a2c64
        @headers.delete('content-encoding')
        body_io = StringIO.new(@body)
        @body.replace Zlib::GzipReader.new(body_io).read
      end
    end
  end
end
