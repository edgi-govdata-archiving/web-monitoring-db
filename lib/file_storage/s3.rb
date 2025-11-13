# frozen_string_literal: true

require 'aws-sdk-s3'

module FileStorage
  class S3
    S3_HOST_PATTERN = /^(?:([^.]+)\.)?s3(?:-([^.]+))?\.amazonaws\.com$/

    def initialize(key: nil, secret: nil, bucket:, region: nil, acl: 'public-read', gzip: false)
      @bucket = bucket
      @region = region || 'us-east-1'
      @client = Aws::S3::Client.new(
        access_key_id: key,
        secret_access_key: secret,
        region: @region
      )
      @acl = acl
      @gzip = gzip
    end

    def contains_url?(url_string)
      get_metadata(url_string).present?
    end

    def get_metadata(path)
      get_metadata!(path)
    # FIXME: should have a more specific error class than ArgumentError here;
    # we could catch errors we don't want to.
    rescue Aws::S3::Errors::NotFound, ArgumentError
      nil
    end

    def get_metadata!(path)
      bucket_path = normalize_full_path(path)
      data = @client.head_object(bucket: @bucket, key: bucket_path)
      {
        last_modified: data.last_modified,
        size: data.content_length,
        content_type: data.content_type,
        content_encoding: data.content_encoding
      }
    end

    def get_file(path)
      bucket_path = normalize_full_path(path)
      object = @client.get_object(bucket: @bucket, key: bucket_path)

      if object.content_encoding == 'gzip'
        Zlib::GzipReader.zcat(object.body)
      else
        object.body.read
      end
    end

    def save_file(path, content, options = nil)
      options ||= {}
      response = @client.put_object(
        bucket: @bucket,
        key: path,
        # TODO: it would be nice to support streaming through the gzip compressor instead of buffering all `content`.
        body: @gzip ? ActiveSupport::Gzip.compress(content.try(:read) || content) : content,
        acl: options.fetch(:acl, @acl),
        content_type: options.fetch(:content_type, 'application/octet-stream'),
        content_encoding: @gzip ? 'gzip' : nil
      )
      { url: url_for_file(path), meta: response }
    end

    def url_for_file(path)
      "https://#{@bucket}.s3.amazonaws.com/#{path}"
    end

    private

    # Determine bucket, path, region info from URIs in the forms:
    # - s3://bucket/file/path.extension
    # - https://bucket.s3.amazonaws.com/file/path.extension
    # - https://s3-region.amazonaws.com/bucket/file/path.extension
    def parse_s3_url(url_string)
      uri = URI.parse(url_string)
      if uri.scheme == 's3'
        { bucket: uri.host, path: uri.path[1..-1], region: nil }
      elsif ['http', 'https'].include?(uri.scheme)
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
