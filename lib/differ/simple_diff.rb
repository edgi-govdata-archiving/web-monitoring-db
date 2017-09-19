module Differ
  class SimpleDiff
    def initialize(url)
      @url = url
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
          JSON.parse(response.body)
        else
          response.body
        end

      raise Api::DynamicError.new(body, response.code) if response.code >= 400
      body
    end
  end
end
