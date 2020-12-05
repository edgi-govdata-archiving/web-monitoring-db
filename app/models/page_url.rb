# PageUrl is a critical part of each Page model. Pages do not represent a
# single URL -- pages are often reachable from multiple URLs (sometimes at
# the same time; sometimes because a page moves over time) and different
# pages are sometimes reached from the same URL at different points in time.
#
# Pages have many PageUrls, each representing a single URL associated with
# the page. They can also store timeframe information and analyst-supplied
# notes (both are human-managed, anecdocal information that should not be
# treated as mechanistic, measured, objective values -- for example, we can
# never measure the true valid timeframe for a (page, URL) combination
# because we only sample the responses from a web server on a regular basis
# and cannot know exactly when a web server stopped responding to a given
# URL -- without external information gathered by had, the best we can
# technically say is "sometime between version x and version y").
class PageUrl < ApplicationRecord
  include UuidPrimaryKey

  belongs_to :page, foreign_key: :page_uuid, required: true, inverse_of: :urls

  # NOTE: consider switching to a tsrange instead of two columns for the
  # timeframe here if Rails decides on a plan for:
  #   https://github.com/rails/rails/issues/39833
  # Then this can just be: `where('timeframe @> ?::timestamp', Time.now)`
  scope(:current, lambda do
    now = Time.now
    where('from_time <= ?', now).where('to_time > ?', now)
  end)

  validates :url,
            allow_nil: false,
            format: {
              # We have some valid URLs that URI.parse doesn't like, so use
              # this looser, but workable regex for now.
              # (Example: "https://www.fws.gov/letsgooutside/docs/kids/RRNatureNotebook_JuneJuly_11[1].pdf")
              with: /\A(https?|ftp):\/\/([^\/@]+@)?([^\/]+\.[^\/]{2,})/,
              message: 'must be a valid HTTP(S) or FTP URL with a host'
            }
  before_save :ensure_url_key

  def self.create_url_key(url)
    Surt.surt(url)
  end

  def url=(value)
    # Reset url_key to ensure it gets recalculated
    self.url_key = nil if value != url
    super(value)
  end

  # To simplify query logic, we want to make sure `from_time` and `to_time`
  # always have a value. Unfortunately, Rails doesn't deal too well with
  # Postgres's +/-infinity dates. You can only set them as a string (not a
  # float) even though they read back as +/-Float::INFINITY!
  # These custom setters let us set floats for sanity, and also converts
  # `nil` to +/-infinity as appropriate, since they have the same meaning as
  # far as we're concerned.
  def from_time=(value)
    value = '-infinity' if value.nil? || value == -Float::INFINITY
    super(value)
  end

  # See note above on `from_time=()`.
  def to_time=(value)
    value = 'infinity' if value.nil? || value == Float::INFINITY
    super(value)
  end

  def ensure_url_key
    self.url_key ||= PageUrl.create_url_key(url)
  end
end
