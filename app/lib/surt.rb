require 'addressable/uri'

module Surt
  def self.surt(url, options = {})
    Surt::Format.format(canonicalize(url, options), options)
  end

  def self.canonicalize(url, options = {})
    Surt::Canonicalize.url(parse_url(url), options).to_s
  end

  def self.format(url, options = {})
    Surt::Format.format(parse_url(url), options)
  end

  private

  def self.parse_url(url)
    url = url.strip.gsub(/[\r\n\t]/, '').gsub(/\s/, '%20')
    url = "http://#{url}" unless url.match?(/^[^:\/.]*:/)
    Addressable::URI.parse(url)
  end
end
