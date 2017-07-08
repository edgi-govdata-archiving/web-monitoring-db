module JwtTools
  class JwtAuthStrategy < Devise::Strategies::Base
    def valid?
      request.headers['Authorization'].present?
    end

    def authenticate!
      Rails.logger.debug "Claim data: '#{claims}'"
      return fail! unless claims
      return fail! unless claims.key?('sub')
      user_id = claims['sub'].match(/^User:(\d+)$/).try(:[], 1)
      return fail! unless user_id
      success! User.find_by_id user_id
    end

    protected

    def claims
      strategy, token = request.headers['Authorization'].split(' ')
      return nil if (strategy || '').casecmp('bearer') != 0

      JwtCoder.decode(token)
    end
  end
end
