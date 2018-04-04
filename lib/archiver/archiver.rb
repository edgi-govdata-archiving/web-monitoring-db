require 'digest'
require 'httparty'

module Archiver
  REDIRECT_LIMIT = 10

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

  # Primary API ----------

  def self.archive(url, expected_hash: nil)
    response = HTTParty.get(url, limit: REDIRECT_LIMIT)
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
    store.contains_url?(url) || external_archive_url?(url)
  end

  def self.hash_content_at_url(url)
    response = HTTParty.get(url, limit: REDIRECT_LIMIT)
    hash_content(response.body)
  end

  def self.hash_content(content)
    Digest::SHA256.hexdigest(content)
  end

  def self.external_archive_url?(url)
    allowed_hosts.any? {|base| url.starts_with?(base)}
  end
end
