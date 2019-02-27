require 'digest'
require 'httparty'

module Archiver
  REDIRECT_LIMIT = 10
  MAXIMUM_TRIES = 3

  # Configuration ----------

  def self.store=(store)
    @store = store
  end

  def self.store
    raise StandardError, 'You must set store before archiving.' unless @store

    @store
  end

  def self.allowed_hosts=(hosts)
    hosts = [] if hosts.nil?
    hosts = hosts.split(' ') if hosts.is_a?(String)
    unless hosts.is_a?(Enumerable) && hosts.all? {|host| host.is_a?(String)}
      raise StandardError, 'Allowed hosts must be a string or enumerable of strings'
    end

    @allowed_hosts = hosts
  end

  def self.allowed_hosts
    @allowed_hosts || []
  end

  def self.public_hosts=(hosts)
    hosts = [] if hosts.nil?
    hosts = hosts.split(' ') if hosts.is_a?(String)
    unless hosts.is_a?(Enumerable) && hosts.all? {|host| host.is_a?(String)}
      raise StandardError, 'Public hosts must be a string or enumerable of strings'
    end
    @public_hosts = hosts
  end

  def self.public_hosts
    @public_hosts || []
  end

  # Primary API ----------

  def self.archive(url, expected_hash: nil, force: false)
    # If the hash is already in the store, there's no reason to load & verify.
    if expected_hash && !force
      hash_url = store.url_for_file(expected_hash)
      return { url: hash_url, hash: expected_hash } if store.contains_url?(hash_url)
    end

    response = retry_request do
      HTTParty.get(url, limit: REDIRECT_LIMIT)
    end

    hash = hash_content(response.body)
    if expected_hash && expected_hash != hash
      raise Api::MismatchedHashError.new(url, expected_hash)
    end

    url =
      if already_archived?(url)
        url
      else
        store.save_file(
          hash,
          response.body,
          content_type: response.headers['Content-Type']
        )
        store.url_for_file(hash)
      end

    { url: url, hash: hash }
  end

  def self.already_archived?(url)
    external_archive_url?(url) || store.contains_url?(url)
  end

  def self.public_archive_url?(url)
    external_archive_url?(url) || public_hosts.any? {|base| url.starts_with?(base)}
  end

  def self.hash_content_at_url(url)
    response = retry_request do
      HTTParty.get(url, limit: REDIRECT_LIMIT)
    end
    hash_content(response.body)
  end

  def self.hash_content(content)
    Digest::SHA256.hexdigest(content)
  end

  def self.external_archive_url?(url)
    allowed_hosts.any? {|base| url.starts_with?(base)}
  end

  def self.get_file_from_uri(uri)
    # HTTP GET the file if its URI belongs to a public host.
    if public_archive_url?(uri)
      response = retry_request do
        HTTParty.get(uri, limit: REDIRECT_LIMIT)
      end
    # Try getting a file from configured storage if it isn't public.
    else
      response = self.store.get_file(uri)
    end

    return response
  end

  # Auto-retry requests that error out or have gateway errors
  def self.retry_request(tries: MAXIMUM_TRIES)
    (1..tries).each do |attempt|
      begin
        response = yield
        return response if attempt >= tries || (response.code != 503 && response.code != 504)
      rescue HTTParty::ResponseError, Timeout::Error => error
        raise error if attempt >= tries
      end

      sleep(attempt**2)
    end
  end
end
