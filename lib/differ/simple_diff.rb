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
      options, no_cache = extract_local_options(options)
      key = generate_cache_key(change, options)

      Rails.cache.fetch("diff/#{key}", expires_in: 2.weeks, force: no_cache) do
        generate_diff(change, options)
      end
    end

    def cache_key(change, options = nil)
      options, = extract_local_options(options)
      generate_cache_key(change, options)
    end

    protected

    # Returns an options object with options for this class itself split out
    # into separate return values.
    def extract_local_options(options)
      options ||= {}
      no_cache = options[:cache] == 'false'
      options = options.reject {|key, _| key.to_s == 'cache'}

      [options, no_cache]
    end

    def generate_diff(change, options)
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

    def generate_cache_key(change, options)
      # Special case: we don't include `format=json`. Clients often include this
      # to handle bad response headers from an old differ
      # TODO: remove special case for `format=json` when possible
      diff_params = options
        .reject {|key, value| key.to_s == 'format' && value == 'json'}
        .sort.collect {|key, value| "#{key}=#{value}"}
        .join('&')

      diff_id = @url.sub(/^https?:\/\//, '')

      "#{diff_id}?#{diff_params}/#{change.api_id}/#{Differ.cache_date.iso8601}"
    end
  end
end
