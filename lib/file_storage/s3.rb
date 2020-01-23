require 'aws-sdk-s3'

module FileStorage
  class S3
    def initialize(key: nil, secret: nil, bucket:, region: nil, acl: 'public-read')
      @bucket = bucket
      @region = region || 'us-east-1'
      @client = Aws::S3::Client.new(
        access_key_id: key,
        secret_access_key: secret,
        region: @region
      )
      @acl = acl
    end

    def contains_url?(url_string)
      # details = parse_s3_url(url_string)
      # return false if details.nil? || details[:bucket] != @bucket
      bucket_path = normalize_full_path(url_string)

      @client.head_object(bucket: @bucket, key: bucket_path).present?
    rescue Aws::S3::Errors::NotFound
      false
    # FIXME: should have a more specific error class here; we could
    # catch errors we don't want to.
    rescue ArgumentError
      false
    end

    def get_file(path)
      bucket_path = normalize_full_path(path)
      @client.get_object(bucket: @bucket, key: bucket_path).body.read
    end

    def save_file(path, content, options = nil)
      options ||= {}
      response = @client.put_object(
        bucket: @bucket,
        key: path,
        body: content,
        acl: options.fetch(:acl, @acl),
        content_type: options.fetch(:content_type, 'application/octet-stream')
      )
      { url: url_for_file(path), meta: response }
    end

    def url_for_file(path)
      "https://#{@bucket}.s3.amazonaws.com/#{path}"
    end

    private

    S3_HOST_PATTERN = /^(?:([^.]+)\.)?s3(?:-([^.]+))?\.amazonaws\.com$/.freeze

    # Determine bucket, path, region info from URIs in the forms:
    # - s3://bucket/file/path.extension
    # - https://bucket.s3.amazonaws.com/file/path.extension
    # - https://s3-region.amazonaws.com/bucket/file/path.extension
    def parse_s3_url(url_string)
      uri = URI.parse(url_string)
      if uri.scheme == 's3'
        { bucket: uri.host, path: uri.path[1..-1], region: nil }
      elsif uri.scheme == 'http' || uri.scheme == 'https'
        aws_host = uri.host.match(S3_HOST_PATTERN)
        return unless aws_host

        if aws_host[1]
          { bucket: aws_host[1], path: uri.path[1..-1], region: aws_host[2] }
        else
          paths = uri.path.split('/', 3)
          { bucket: paths[1], path: paths[2], region: aws_host[2] }
        end
      end
    end

    # Get a valid bucket path from a complete URL, S3 URI, or path. If a URL
    # or S3 URI for a different bucket, this raises ArgumentError.
    def normalize_full_path(path)
      if path.match?(/^\w+:\/\//)
        details = parse_s3_url(path)
        if details.nil? || details[:bucket] != @bucket
          raise ArgumentError, "The URL '#{path}' does not belong to this storage object"
        end

        details[:path]
      else
        path
      end
    end
  end
end
