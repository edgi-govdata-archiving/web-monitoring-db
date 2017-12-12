module Differ
  class SimpleDiff
    def initialize(url, type = nil)
      @url = url

      if type
        @url += '/' unless @url.ends_with?('/')
        @url += URI.encode_www_form_component(type)
      end
    end

    def diff(change, options = nil)
      options ||= {}
      query = options.merge(
        a: change.from_version.uri,
        a_hash: change.from_version.version_hash,
        b: change.version.uri,
        b_hash: change.version.version_hash
      )

      response = HTTParty.get(@url, query: query)

      # TODO: get our simple differ to return correct Content-Type header
      # and remove check for magical 'format' query arg
      body =
        if response.request.format == :json || options['format'] == 'json'
          begin
            JSON.parse(response.body)
          rescue JSON::ParserError
            response.body
          end
        else
          response.body
        end

      if response.code >= 400
        message = body.is_a?(Hash) && body['error'] || body
        raise Api::DynamicError.new(message, response.code)
      end

      body
    end
  end
end
