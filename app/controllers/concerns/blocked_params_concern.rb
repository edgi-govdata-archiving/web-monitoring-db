# Block unauthenticated requests that use certain params with a 403 (Forbidden)
# error. This can be used to prevent abuse of options that may cause expensive
# operations.
module BlockedParamsConcern
  extend ActiveSupport::Concern

  module ClassMethods
    attr_reader :blocked_public_params

    private

    def block_params_for_public_users(blocked_params)
      @blocked_public_params = Set.new(blocked_params.collect &:to_s)
    end
  end

  included do
    before_action :raise_for_non_public_params!
  end

  protected

  def raise_for_non_public_params!
    if !current_user && self.class.blocked_public_params&.intersect?(params.keys)
      names = self.class.blocked_public_params.collect {|p| "`#{p}`"}.join(', ')
      raise Api::ForbiddenError, "You must be logged in to use the params: #{names}"
    end
  end
end
