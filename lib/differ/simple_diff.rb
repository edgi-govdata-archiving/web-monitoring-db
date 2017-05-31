module Differ
  class SimpleDiff
    def initialize(url)
      @url = url
    end

    def diff(change, options = nil)
      options ||= {}
      query = options.merge(
        a: change.from_version.uri,
        b: change.version.uri
      )

      response = HTTParty.get(@url, query: query)

      # TODO: get our simple differ to return correct Content-Type header
      # and remove check for magical 'format' query arg
      if response.request.format == :json || options['format'] == 'json'
        JSON.parse(response.body)
      else
        response.body
      end
    end
  end
end
