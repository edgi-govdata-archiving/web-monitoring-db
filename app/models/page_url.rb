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

  # NOTE: consider switching to a tsrange instead of two columns for the
  # timeframe here if Rails decides on a plan for:
  #   https://github.com/rails/rails/issues/39833
  # Then this can just be: `where('timeframe @> ?::timestamp', Time.now)`
  def self.current(at_time = nil)
    at_time ||= Time.now
    where('from_time <= ?', at_time).where('to_time > ?', at_time)
  end

  # url is immutable -- the whole reason for this record is to map a URL to a
  # page, so the URL cannot be updated. Once the record has been created,
  # you should delete the record and create a new one instead.
  def url=(value)
    if persisted? && value != url
      raise TypeError, '`url` can\'t be modified after a PageUrl has been created'
    end

    # Reset url_key to ensure it gets recalculated
    self.url_key = nil if value != url
    super(value)
  end

  # To simplify query logic, we want to make sure `from_time` and `to_time`
  # always have a value. Convert `nil` to the appropriate +/-infinity value
  # here as a convenience.
  #
  # NOTE: Rails has a bug with setting +/-Float::INFINITY for timestamp
  # fields, even though that's the type of value it gives you when it reads
  # +/-infinity dates out of the database. ¯\_(ツ)_/¯
  # However, a hacky fix we've implemented to solve another bug also solves
  # this, so we can safely use Float::INFINITY in this project.
  # See `config/initializers/active_record_extras.rb` for more.
  def from_time=(value)
    value = -Float::INFINITY if value.nil?
    super(value)
  end

  # See note above on `from_time=()`.
  def to_time=(value)
    value = Float::INFINITY if value.nil?
    super(value)
  end

  def ensure_url_key
    self.url_key ||= PageUrl.create_url_key(url)
  end
end
