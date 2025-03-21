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
    unless hosts.is_a?(Enumerable) && hosts.all?(String)
      raise StandardError, 'Allowed hosts must be a string or enumerable of strings'
    end

    @allowed_hosts = hosts
  end

  def self.allowed_hosts
    @allowed_hosts || []
  end

  # Primary API ----------

  def self.archive(url, expected_hash: nil, force: false)
    # If the hash is already in the store, there's no reason to load & verify.
    if expected_hash && !force
      hash_url = store.url_for_file(expected_hash)
      meta = store.get_metadata(hash_url)
      return { url: hash_url, hash: expected_hash, length: meta[:size] } if meta
    end

    response = retry_request do
      HTTParty.get(url, limit: REDIRECT_LIMIT)
    end

    hash = hash_content(response.body)
    if expected_hash && expected_hash != hash
      raise Api::MismatchedHashError.new(url, expected_hash, hash)
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

    { url:, hash:, length: response.body.bytesize }
  end

  def self.already_archived?(url)
    external_archive_url?(url) || store.contains_url?(url)
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
