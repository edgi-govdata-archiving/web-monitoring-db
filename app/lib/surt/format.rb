module Surt::Format
  DEFAULT_OPTIONS = {
    include_scheme: false,
    include_trailing_comma: false
  }.freeze

  # Format a URL as a SURT string.
  #
  # == Parameters:
  # url::
  #   The URL to format as SURT as a URI object.
  # options::
  #   Configuration for how to format the URL.
  #
  # == Returns:
  # The SURT-formatted URL as a string
  def self.url(url, options = {})
    options = DEFAULT_OPTIONS.clone.merge(options)
    result = ''

    if options[:include_scheme]
      delimiter = scheme == 'dns' ? '' : '//'
      result = "#{url.scheme}:#{delimiter}("
    elsif url.host.blank?
      result = "#{url.scheme}:"
    end

    result += host(url, options) if url.host.present?

    if url.path.present?
      result += url.path
    elsif url.query.present? || url.fragment.present?
      result += '/'
    end

    result += "?#{url.query}" if url.query.present?
    result += "##{url.fragment}" if url.fragment.present?

    result
  end

  def self.host(url, options)
    host = url.host.split('.').reverse.join(',')
    host = "#{url.userinfo}@#{host}" if url.userinfo
    host = "#{host}:#{url.port}" if url.port
    host += ',' if options[:include_trailing_comma]
    "#{host})"
  end
end
