# frozen_string_literal: true

# Block unauthenticated requests that use certain params with a 403 (Forbidden)
# error. This can be used to prevent abuse of options that may cause expensive
# operations.
module BlockedParamsConcern
  extend ActiveSupport::Concern

  module ClassMethods
    attr_reader :blocked_public_params

    private

    # Raise an exception on any non-logged-in request that uses the specified
    # params.
    #
    # @param actions [:all, Array<Symbol>] Only block the params on these
    #        actions. If `:all` or not set, blocking is applied to all actions.
    # @param params [Array<Symbol, String>] Param names to block.
    #
    # @example
    #   class MyController
    #     include BlockedParamsConcern
    #     block_params_for_public_users actions: [:index, :show]
    #                                   params: [:bad, :params, :here]
    #   end
    def block_params_for_public_users(actions: nil, params:)
      actions = nil if actions == :all
      actions = [actions] unless actions.nil? || actions.is_a?(Array)
      actions = actions&.collect(&:to_s)

      @blocked_public_params ||= {}
      @blocked_public_params[actions] = params.collect(&:to_s)
    end
  end

  included do
    before_action :check_non_public_params!
  end

  protected

  def check_non_public_params!
    return unless self.class.blocked_public_params

    blocked = self.class.blocked_public_params.flat_map do |actions, params|
      actions.nil? || actions.include?(action_name) ? params : nil
    end

    raise_for_non_public_params!(blocked)
  end

  def raise_for_non_public_params!(blocked_params)
    if !current_user && blocked_params.intersect?(params.keys)
      names = blocked_params.collect {|p| "`#{p}`"}.join(', ')
      raise Api::ForbiddenError, "You must be logged in to use the params: #{names}"
    end
  end
end
