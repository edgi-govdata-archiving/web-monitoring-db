require 'aws-sdk'

module FileStorage::S3
  def initialize(key:, secret:, bucket:, region: nil)
    @bucket = bucket
    @region = region || 'us-east-1'
    @client = Aws::S3::Client.new(
      access_key_id: key,
      secret_access_key: secret,
      region: @region
    )
  end

  def contains_url?(url_string)
    details = parse_s3_url(url_string)
    details && details[:bucket] == @bucket
  end

  def get_file(path)
    @client.get_object(bucket: @bucket, key: path).get.body
  end

  def save_file(path, content, options = nil)
    options ||= {}
    response = @client.put_object(
      bucket: @bucket,
      key: path,
      body: content,
      acl: options.fetch(:acl, 'public-read'),
      content_type: options.fetch(:content_type, 'application/octet-stream')
    )
    { url: url_for_file(path), meta: response }
  end

  def url_for_file(path)
    "https://#{@bucket}.s3.amazonaws.com/#{path}"
  end

  private

  S3_HOST_PATTERN = /^(?:([^.]+)\.)?s3(?:-([^.]+))?\.amazonaws\.com$/

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
end
