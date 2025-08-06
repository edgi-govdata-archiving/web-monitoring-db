require 'addressable/uri'

module Surt::Canonicalize
  # TODO: add remove_directory_index option? Based on Purell:
  # https://github.com/PuerkitoBio/purell#api
  # https://github.com/PuerkitoBio/purell/blob/f619812e3caf603a8df60a7ec6f2654b703189ef/purell.go#L84
  #
  # TODO: Add fixing malformed IPv4 address like Internet Archive's SURT does:
  # `http://10.0.258` → `http://10.0.1.2`
  DEFAULT_OPTIONS = {
    decode_dword_host: true,
    decode_hex_host: true,
    decode_octal_host: true,
    lowercase_host: true,
    lowercase_path: true,
    lowercase_query: true,
    lowercase_scheme: true,
    remove_default_port: true,
    remove_dot_segments: true,
    remove_empty_query: true,
    # TODO: add `remove_empty_fragment`? Which would also be in SAFE_OPTIONS.
    remove_fragment: false,
    remove_non_hashbang_fragment: true,
    remove_sessions_in_path: true,
    remove_sessions_in_query: true,
    remove_repeated_slashes: true,
    # Removing trailing slashes in paths, except if the path is *just* "/".
    remove_trailing_slash: true,
    # Replace a root path ("/") with no path at all. For example: "http://abc.com/" → "http://abc.com"
    remove_root_path: false,
    remove_userinfo: true,
    remove_www: true,
    sort_query: true
  }.freeze

  SAFE_KEYS = [:lowercase_host, :lowercase_scheme, :remove_default_port, :remove_empty_query].freeze
  SAFE_OPTIONS = DEFAULT_OPTIONS.to_h { |k, _v| [k, SAFE_KEYS.include?(k)] }.freeze

  # TODO: consider additional ports? Both Java and Python SURT only do these two, but there are plenty of others that
  #  would be relevant. Note we currently skip all canonicalization for other schemes anyway (making this a moot
  #  question for now), although neither Python nor Java SURT do so. We might want to relax that in the future.
  #  Addressable has a nice, stealable list: https://github.com/sporkmonger/addressable/blob/3450895887d0a1770660d8831d1b6fcfed9bd9d6/lib/addressable/uri.rb#L89-L103
  DEFAULT_PORTS = {
    'http' => 80,
    'https' => 443
  }.freeze

  PATH_SESSION_IDS = [
    /^(.*\/)(\((?:[a-z]\([0-9a-z]{24}\))+\)\/)([^?]+\.aspx.*)$/i,
    /^(.*\/)(\([0-9a-z]{24}\)\/)([^?]+\.aspx.*)$/i
  ].freeze

  # TODO: should we refactor this into a more readable format? e.g:
  # [
  #   {param_to_remove: /regex or string to match value/},
  #   {param_to_remove1: /regex for value/, param_to_remove2: /regex for value/}
  # ]
  # TODO: should rename this -- it's not really just session IDs anymore.
  QUERY_SESSION_IDS = [
    /^(.*)(?:jsessionid=[0-9a-zA-Z]{32})(?:&(.*))?$/i,
    /^(.*)(?:phpsessid=[0-9a-zA-Z]{32})(?:&(.*))?$/i,
    /^(.*)(?:sid=[0-9a-zA-Z]{32})(?:&(.*))?$/i,
    /^(.*)(?:ASPSESSIONID[a-zA-Z]{8}=[a-zA-Z]{24})(?:&(.*))?$/i,
    /^(.*)(?:cfid=[^&]+&cftoken=[^&]+)(?:&(.*))?$/i,
    /^(.*)(?:utm_source=[^&]+)(?:&(.*))?$/i,
    /^(.*)(?:utm_medium=[^&]+)(?:&(.*))?$/i,
    /^(.*)(?:utm_term=[^&]+)(?:&(.*))?$/i,
    /^(.*)(?:utm_content=[^&]+)(?:&(.*))?$/i,
    /^(.*)(?:utm_campaign=[^&]+)(?:&(.*))?$/i,
    /^(.*)(?:sms_ss=[^&]+)(?:&(.*))?$/i,
    /^(.*)(?:awesm=[^&]+)(?:&(.*))?$/i,
    /^(.*)(?:xtor=[^&]+)(?:&(.*))?$/i,
    /^(.*)(?:nrg_redirect=\d+)(?:&(.*))?$/i
  ].freeze

  OCTAL_IP = /^(0[0-7]*)(\.[0-7]+)?(\.[0-7]+)?(\.[0-7]+)?$/
  WWW_SUBDOMAIN = /(^|\.)www\d*\./


  # TODO: Internet Archive's SURT uses this crazy character set, but only one
  #  test fails if we just use Addressable's standard set. Maybe drop this?
  #  Also validate against the original Java version:
  #  https://github.com/iipc/webarchive-commons/blob/5fb641b7ff3c63ade0eb39782fc8b1982ea27330/src/main/java/org/archive/url/BasicURLCanonicalizer.java#L219-L275
  URL_SPECIAL_CHARACTERS = '!"$&\'()*+,-./:;<=>?@[\]^_`{|}~'.freeze
  SAFE_CHARACTERS = "0-9a-zA-Z#{Regexp.escape(URL_SPECIAL_CHARACTERS)}".freeze

  # Canonicalize a URL. This is the normal entrypoint to this module.
  #
  # == Parameters:
  # url::
  #   The URL to canonicalize as a URI object.
  # options::
  #   Most canonicalization options are optional and can be explicitly enabled
  #   or disabled using a hash of options.
  #
  # == Returns:
  # The canonicalized URL as a new URI object.
  #
  def self.url(raw_url, options = {})
    return raw_url unless ['http', 'https'].include?(raw_url.scheme.downcase)

    url = raw_url.clone
    options = DEFAULT_OPTIONS.clone.merge(options)
    scheme(url, options)
    userinfo(url, options)
    host(url, options)
    path(url, options)
    query(url, options)
    fragment(url, options)
    url
  end

  def self.scheme(url, options)
    url.scheme = url.scheme.downcase if options[:lowercase_scheme]
  end

  def self.userinfo(url, options)
    url.user = url.password = nil if options[:remove_userinfo]
    # FIXME: option to prevent this escaping change?
    url.user = escape_minimally(url.user) if url.user
    url.password = escape_minimally(url.password) if url.password
  end

  def self.host(url, options)
    # FIXME: option to prevent this escaping change?
    #  probably should understand better whether we still need 1 level of unescaping and re-escaping for the other
    #  stuff here, though (e.g. Punycode/IDNA ASCII encoding)!
    hostname = unescape_repeatedly(url.host)
    hostname = Addressable::IDNA.to_ascii(hostname)
    hostname = hostname.downcase if options[:lowercase_host]
    hostname = hostname.sub(WWW_SUBDOMAIN, '\1') if options[:remove_www]
    # FIXME: this matches the Python implementation's behavior, but it *looks* like the first gsub here may have been a
    #  transcription error from the original Java, which looks for any sequence of 2+ dots (/\.\.+/):
    #  https://github.com/iipc/webarchive-commons/blob/5fb641b7ff3c63ade0eb39782fc8b1982ea27330/src/main/java/org/archive/url/BasicURLCanonicalizer.java#L58-L59
    #  Need to test Java; figure out right thing to do. Maybe ask on IA Slack.
    hostname = hostname.gsub('..', '.').gsub(/(^\.+)|(\.+$)/, '')

    if options[:decode_dword_host] && hostname.match?(/^\d+$/)
      hostname = dword_to_decimal_ip(hostname)
    elsif options[:decode_hex_host] && hostname.start_with?('0x')
      hostname = dword_to_decimal_ip(hostname.hex)
    elsif options[:decode_octal_host] && hostname.match?(OCTAL_IP)
      hostname = hostname.split('.').collect(&:oct).join('.')
    end

    url.host = escape(hostname)
    url.port = nil if url.port == DEFAULT_PORTS[url.scheme] && options[:remove_default_port]
  end

  def self.path(url, options)
    # FIXME: option to prevent this escaping change?
    #  probably should understand better whether we still need 1 level of unescaping and re-escaping for the other
    #  stuff here, though (e.g. Punycode/IDNA ASCII encoding)!
    path = unescape_repeatedly(url.path).strip
    path = '/' if path.empty?
    path = path.downcase if options[:lowercase_path]

    if options[:remove_sessions_in_path]
      PATH_SESSION_IDS.each {|expression| path = path.gsub(expression, '\1\3')}
    end

    items = path.split('/', -1)[1..-1] || []

    if options[:remove_dot_segments]
      items = items.each_with_object([]) do |item, accumulator|
        if item == '..'
          accumulator.pop
        elsif item != '.'
          accumulator.push(item)
        end
      end
    end

    if options[:remove_repeated_slashes] && items.length > 1
      items = [
        *items[0...-1].reject {|item| item == ''},
        items[-1]
      ]
    end

    path = "#{path[0] || ''}#{items.join('/')}"

    if options[:remove_trailing_slash] && path.length > 1
      path = path.chomp('/')
    elsif options[:remove_root_path] && path == '/'
      path = ''
    end

    url.path = escape(path)
  end

  def self.query(url, options)
    if url.query.present?
      if options[:remove_sessions_in_query]
        # TODO: could this be better handled without regexes?
        url.query = QUERY_SESSION_IDS.reduce(url.query) do |query, expression|
          query.gsub(expression, '\1\2')
        end.sub(/&$/, '')
      end
      url.query = url.query.downcase if options[:lowercase_query]
      url.query = (url.normalized_query(:sorted) || '') if options[:sort_query]
    end

    url.query = nil if url.query.blank? && options[:remove_empty_query]
  end

  def self.fragment(url, options)
    if options[:remove_fragment]
      url.fragment = nil
    elsif options[:remove_non_hashbang_fragment]
      url.fragment = nil if url.fragment && url.fragment[0] != '!'
    end
  end

  def self.dword_to_decimal_ip(raw_dword)
    dword = raw_dword.to_i
    [24, 16, 8, 0].collect {|shift| (dword >> shift) & 0xff}.join('.')
  end

  def self.unescape_repeatedly(raw_string)
    unescaped = Addressable::URI.unencode_component(raw_string)
    unescaped == raw_string ? unescaped : unescape_repeatedly(unescaped)
  end

  # Take a string that has been re-escaped any number of times and make sure it
  # is only escaped once.
  def self.escape_minimally(raw_string)
    Addressable::URI.encode_component(unescape_repeatedly(raw_string))
  end

  def self.escape(raw_string)
    Addressable::URI.encode_component(raw_string, SAFE_CHARACTERS)
  end
end
