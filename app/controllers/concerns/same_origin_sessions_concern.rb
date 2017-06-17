# Make sessions available only to requests from the same host as the server.
#
# This means sessions work for people browsing this site directly, but not for
# cross-origin requests or requests not coming from browsers (unless the Referer
# header is manually added). Cross-origin requests must use a different,
# self-managed means of authentication (e.g. HTTP auth, tokens, etc).
#
# It generally mitigates attacks where a random web site might make a request
# to the APIs this service hosts and be able to get data or make changes on a
# browsing user's behalf without their knowledge.
module SameOriginSessionsConcern
  extend ActiveSupport::Concern

  included do
    before_action :disable_session_for_cross_origin_request
  end

  protected

  def disable_session_for_cross_origin_request
    # Nil referers are OK -- e.g. a user navigating directly to the page has no
    # referer. The security case we're concerned about always has a referer.
    if referring_host && request.host != referring_host
      # Clear the session, but skip committing when writing response
      request.session_options[:skip] = true
      request.session.clear
    end
  end

  def referring_host
    URI.parse(request.referer).host
  rescue
    nil
  end
end
