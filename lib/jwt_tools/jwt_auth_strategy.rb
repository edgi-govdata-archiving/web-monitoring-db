module JwtTools
  class JwtAuthStrategy < Devise::Strategies::Base
    def valid?
      request.headers['Authorization'].present?
    end

    def authenticate!
      return pass unless claims && claims.key?('sub')

      user_id = claims['sub'].match(/^User:(\d+)$/).try(:[], 1)
      return pass unless user_id

      user = User.find_by_id(user_id)
      if user
        success! user
      else
        fail!
      end
    end

    protected

    def claims
      strategy, token = request.headers['Authorization'].split(' ')
      return nil if (strategy || '').casecmp('bearer') != 0

      JwtCoder.decode(token)
    end
  end
end
