require 'test_helper'

class SurtTest < ActiveSupport::TestCase
  # Give us a nice syntax so we can visually align output vs. input
  def assert_canonicalized(expected, url, message = nil, options = {})
    assert_equal(expected, Surt.canonicalize(url, options), message)
  end

  test 'it does not modify canonical URLs' do
    assert_canonicalized(
      'http://archive.org/index.html',
      'http://archive.org/index.html'
    )
  end

  test 'it removes "www[digit?]" subdomains' do
    assert_canonicalized(
      'http://alexa.com/',
      'http://www.alexa.com/',
      'It failed to remove a "www." subdomain'
    )
    assert_canonicalized(
      'http://archive.org/',
      'http://www34.archive.org/',
      'It failed to remove a "www[digit]." subdomain'
    )
  end

  test 'it cleans up querystrings' do
    assert_canonicalized(
      'http://archive.org/index.html',
      'http://archive.org/index.html?',
      'It failed to remove an empty query'
    )
    assert_canonicalized(
      'http://archive.org/index.html?a=b&b=b',
      'http://archive.org/index.html?b=b&a=b',
      'It failed to alphabetized the query'
    )
    assert_canonicalized(
      'http://archive.org/index.html?a=b&b=a&b=b',
      'http://archive.org/index.html?b=a&b=b&a=b',
      'It failed to alphabetized a query with repeat keys'
    )
  end

  test 'it singly escapes deeply nested escaped strings' do
    assert_canonicalized(
      'http://host/%25',
      'http://host/%25%32%35'
    )
    assert_canonicalized(
      'http://host/%25%25',
      'http://host/%25%32%35%25%32%35'
    )
    assert_canonicalized(
      'http://host/%25',
      'http://host/%2525252525252525'
    )
    assert_canonicalized(
      'http://host/asdf%25asd',
      'http://host/asdf%25%32%35asd'
    )
    assert_canonicalized(
      'http://host/%25%25%25asd%25%25',
      'http://host/%%%25%32%35asd%%'
    )
  end

  test 'it removes unnecessary escapes' do
    assert_canonicalized(
      'http://168.188.99.26/.secure/www.ebay.com',
      'http://%31%36%38%2e%31%38%38%2e%39%39%2e%32%36/%2E%73%65%63%75%72%65/%77%77%77%2E%65%62%61%79%2E%63%6F%6D/'
    )
    assert_canonicalized(
      'http://host%23.com/~a!b@c%23d$e%25f^00&11*22(33)44_55+',
      'http://host%23.com/%257Ea%2521b%2540c%2523d%2524e%25f%255E00%252611%252A22%252833%252944_55%252B'
    )
  end

  test 'it decimal encodes IPv4 addresses' do
    assert_canonicalized(
      'http://168.188.99.26/',
      'http://168.188.99.26',
      'It failed to leave a simple IPv4 alone'
    )
    assert_canonicalized(
      'http://15.0.0.1/',
      'http://017.0.0.1',
      'It failed to decode an octal IP'
    )
    assert_canonicalized(
      'http://195.127.0.11/blah',
      'http://3279880203/blah',
      'It failed to decode a DWORD host'
    )
    # Python SURT does some crazy fixing of IPv4 addresses, but I'm not sure
    # it's actually worth supporting here.
    # assert_canonicalized(
    #   'http://10.0.1.2',
    #   'http://10.0.258',
    #   'It did not correct a poorly encoded IPv4'
    # )
  end

  test 'it handles IPv6 addresses' do
    assert_canonicalized(
      'https://[2600:1f18:200d:fb00:2b74:867c:ab0c:150a]/goo',
      'https://[2600:1f18:200d:fb00:2b74:867c:ab0c:150a]/goo/'
    )
  end

  test 'it normalizes and removes dots in path segments' do
    assert_canonicalized(
      'http://google.com/',
      'http://google.com/blah/..',
      'A double-dot did not remove the preceding path segment'
    )
  end

  test 'it removes fragments' do
    assert_canonicalized(
      'http://evil.com/blah',
      'http://evil.com/blah#frag'
    )
    assert_canonicalized(
      'http://evil.com/foo',
      'http://evil.com/foo#bar#baz'
    )
  end

  test 'it does not remove hashbang fragments' do
    assert_canonicalized(
      'http://evil.com/blah#!frag',
      'http://evil.com/blah#!frag'
    )
  end

  test 'it lower-cases host names' do
    assert_canonicalized(
      'http://google.com/',
      'http://GOOgle.com/'
    )
  end

  test 'it removes unnecessary periods in host names' do
    assert_canonicalized(
      'http://google.com/',
      'http://google.com.../'
    )
  end

  test 'it removes invalid URL characters' do
    assert_canonicalized(
      'http://google.com/foobarbaz2',
      "http://google.com/foo\tbar\rbaz\n2"
    )
  end

  test 'it percent-encodes non-IDNA characters' do
    assert_canonicalized(
      'http://%01%C2%80.com/',
      "http://\u0001\u0080.com/"
    )
    assert_canonicalized(
      'http://t%EF%BF%BD%04.82.net/',
      'http://t%EF%BF%BD%04.82.net/'
    )
  end

  test 'it IDNA-encodes host names' do
    assert_canonicalized(
      'http://xn--bcher-kva.ch:8080/',
      "B\u00FCcher.ch:8080"
    )
    assert_canonicalized(
      'http://xn--n3h.com/',
      '☃.com',
      'It failed to IDNA-encode the host name'
    )
  end

  test 'it handles empty paths' do
    assert_canonicalized(
      'http://notrailing.com/',
      'http://notrailing.com'
    )
    assert_canonicalized(
      'http://notrailing.com',
      'http://notrailing.com',
      'An empty path was replaced with a slash even though `remove_root_path: true`',
      remove_root_path: true
    )
  end

  test 'it removes trailing slashes on paths' do
    assert_canonicalized(
      'http://notrailing.com/slash',
      'http://notrailing.com/slash/'
    )
    assert_canonicalized(
      'http://notrailing.com/',
      'http://notrailing.com/'
    )
    assert_canonicalized(
      'http://notrailing.com',
      'http://notrailing.com/',
      'Trailing slashes on an empty path were not removed when `remove_root_path: true`',
      remove_root_path: true
    )
  end

  test 'it removes unnecessary port numbers' do
    assert_canonicalized(
      'http://gotaport.com/',
      'http://gotaport.com:80/'
    )
    assert_canonicalized(
      'https://gotaport.com/',
      'https://gotaport.com:443/'
    )
    assert_canonicalized(
      'http://gotaport.com:1234/',
      'http://gotaport.com:1234/',
      'It failed to keep non-standard port numbers'
    )
  end

  test 'it removes leading and trailing spaces' do
    assert_canonicalized(
      'http://google.com/',
      '  http://google.com/  '
    )
  end

  test 'it removes repeated "/" characters in a path' do
    assert_canonicalized(
      'http://host.com/twoslashes?more//slashes',
      'http://host.com//twoslashes?more//slashes'
    )
  end

  test 'it does not modify mailto: URLs' do
    assert_canonicalized(
      'mailto:foo@example.com',
      'mailto:foo@example.com'
    )
  end

  test 'it removes session IDs from paths' do
    assert_canonicalized(
      'http://example.com/mileg.aspx',
      'http://example.com/(S(4hqa0555fwsecu455xqckv45))/mileg.aspx',
      'It did not remove an ASP_SESSIONID2 session ID'
    )
    assert_canonicalized(
      'http://example.com/mileg.aspx',
      'http://example.com/(4hqa0555fwsecu455xqckv45)/mileg.aspx',
      'It did not remove an unprefixed ASP_SESSIONID2 session ID'
    )
    assert_canonicalized(
      'http://example.com/mileg.aspx?page=sessionschedules',
      'http://example.com/(a(4hqa0555fwsecu455xqckv45)S(4hqa0555fwsecu455xqckv45)f(4hqa0555fwsecu455xqckv45))/mileg.aspx?page=sessionschedules',
      'It did not remove an unprefixed ASP_SESSIONID3 session ID'
    )
    assert_canonicalized(
      'http://example.com/photos/36050182@n05',
      'http://example.com/photos/36050182@N05',
      'It did not leave @ signs alone in the path'
    )
  end

  test 'it removes session IDs from querystrings' do
    assert_canonicalized(
      'http://example.com/x',
      'http://example.com/x?jsessionid=0123456789abcdefghijklemopqrstuv'
    )
    assert_canonicalized(
      'http://example.com/x?x=y',
      'http://example.com/x?jsessionid=0123456789abcdefghijklemopqrstuv&x=y'
    )
    assert_canonicalized(
      'http://example.com/x?x=y',
      'http://example.com/x?x=y&jsessionid=0123456789abcdefghijklemopqrstuv'
    )
    assert_canonicalized(
      'http://example.com/x?x=y',
      'http://example.com/x?x=y&aspsessionidABCDEFGH=ABCDEFGHIJKLMNOPQRSTUVWX'
    )
    assert_canonicalized(
      'http://example.com/x?x=y',
      'http://example.com/x?x=y&phpsessid=0123456789abcdefghijklemopqrstuv'
    )
    assert_canonicalized(
      'http://example.com/x?x=y',
      'http://example.com/x?x=y&sid=9682993c8daa2c5497996114facdc805'
    )
    assert_canonicalized(
      'http://example.com/x?x=y',
      'http://example.com/x?x=y&CFID=1169580&CFTOKEN=48630702'
    )
  end

  test 'it removes tracking identifiers from querystrings' do
    assert_canonicalized(
      'http://example.com/x',
      'http://example.com/x?utm_term=a&utm_medium=social&utm_source=facebook&utm_content=d&utm_campaign=e',
      'It failed to remove `utm_*` query params'
    )
    assert_canonicalized(
      'http://example.com/x',
      'http://example.com/x?sms_ss=abc&awesm=def&xtor=hij&nrg_redirect=267439',
      'It failed to remove assorted tracking query params'
    )
  end

  test 'it formats URLs as SURT' do
    assert_equal('org,archive)/', Surt.format('http://archive.org/'))
    assert_equal('org,archive,xyz)/', Surt.format('http://xyz.archive.org/'))
    assert_equal('org,archive)/goo', Surt.format('http://archive.org/goo'))
    assert_equal('org,archive)/goo/gah', Surt.format('http://archive.org/goo/gah'))
    assert_equal(
      '2600:1f18:200d:fb00:2b74:867c:ab0c:150a)/goo',
      Surt.format('https://[2600:1f18:200d:fb00:2b74:867c:ab0c:150a]/goo')
    )
  end

  test 'it canonicalizes and formats URLs' do
    assert_equal('org,archive)/goo', Surt.surt('http://archive.org/goo/'))
    assert_equal('org,archive)/goo', Surt.surt('http://archive.org/goo/?'))
    assert_equal('org,archive)/goo?a&b', Surt.surt('http://archive.org/goo/?b&a'))
    assert_equal('org,archive)/goo?a=1&a=2&b', Surt.surt('http://archive.org/goo/?a=2&b&a=1'))
    assert_equal(
      '2600:1f18:200d:fb00:2b74:867c:ab0c:150a)/goo',
      Surt.surt('https://[2600:1f18:200d:fb00:2b74:867c:ab0c:150a]/goo/')
    )
  end
end
