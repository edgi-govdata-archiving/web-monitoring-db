require 'addressable/uri'

# Tools for canonicalizing and formatting URLs according to the Internet
# Archive's "Sort-friendly URI Reordering Transform" (SURT) format:
# http://crawler.archive.org/articles/user_manual/glossary.html#surt
#
# For example:
#
#     URL:  https://energy.gov/eere/sunshot/downloads/
#     SURT: gov,energy)/eere/sunshot/downloads
#
# The implementations primarily live in submodules (Canonicalize and Format),
# while the methods here serve as public entry points. See each implementation
# module for a list of options and default values (at the top of each module).
#
# Code in the submodules is generally based on the Internet Archive's Python
# SURT module: https://github.com/internetarchive/surt
# With some added inspiration from Purell: https://github.com/PuerkitoBio/purell
# and normalize_url: https://github.com/rwz/normalize_url
module Surt
  # Canonicalize and format a URL according to SURT.
  def self.surt(url, options = {})
    Surt::Format.url(Surt::Canonicalize.url(parse_url(url), options), options)
  end

  # Canonicalize a URL. The result of this is a URL, not a SURT string.
  def self.canonicalize(url, options = {})
    options = Surt::Canonicalize::SAFE_OPTIONS if options[:safe]
    Surt::Canonicalize.url(parse_url(url), options).to_s
  end

  # Format a URL as SURT without doing any canonicalization or cleanup.
  def self.format(url, options = {})
    Surt::Format.url(parse_url(url), options)
  end

  def self.parse_url(url)
    url = url.strip.gsub(/[\r\n\t]/, '').gsub(/\s/, '%20')
    url = "http://#{url}" unless url.match?(/^[^:\/.]*:/)
    Addressable::URI.parse(url)
  end
end
