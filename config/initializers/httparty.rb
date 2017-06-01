# Temporary bugfix for https://github.com/jnunemaker/httparty/issues/542
# (Response bodies have the wrong string encoding)
# FIXME: remove this when the underlying HTTParty issue is resolved
module HTTParty
  class Request
    private

    def encode_with_ruby_encoding(body, charset)
      return body if body.nil?
      encoding = Encoding.find(charset)
      body.force_encoding(charset)
    rescue
      body
    end
  end
end
