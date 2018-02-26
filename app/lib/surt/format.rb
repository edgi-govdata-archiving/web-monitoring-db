module Surt::Format
  # Format a URL as a SURT string.
  #
  # == Parameters:
  # url::
  #   The URL to format as SURT.
  # options::
  #   Configuration for how to format the URL.
  #
  # == Returns:
  # The SURT-formatted URL as a string
  def self.format(raw_url, options = {})
    raise NotImplementedError
  end
end
