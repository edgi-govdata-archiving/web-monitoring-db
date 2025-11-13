# frozen_string_literal: true

module JwtTools
  module JwtCoder
    def self.private_key=(new_key)
      unless new_key.is_a?(OpenSSL::PKey::RSA)
        new_key = OpenSSL::PKey::RSA.new(format_rsa_private_key(new_key))
      end

      @private_key = new_key
      @public_key = new_key.public_key
    end

    def self.expire_after=(hours)
      @expire_after = hours.to_f.hours
    end

    def self.expire_after
      @expire_after ||= 7.days
    end

    # Encode a hash into a JWT while ensuring correct expiration and signature.
    # If :exp is a key, it can be a Time, Date, or DateTime (not just an int).
    def self.encode(payload)
      raise 'You must set a private key for tokens in order to use JWTs' unless @private_key

      expire_at = payload[:exp] || (Time.now + expire_after)

      payload = payload.dup
      payload[:exp] = expire_at.to_i
      payload[:iat] = Time.now.to_i

      JWT.encode(payload, @private_key, 'RS256')
    end

    def self.decode(token)
      raise 'You must set a private key for tokens in order to use JWTs' unless @private_key

      begin
        # TODO: raise up expiration errors so we can return a special response?
        decoded = JWT.decode(token, @public_key, true, algorithm: 'RS256')
        decoded.first
      rescue StandardError => _error
        nil
      end
    end

    # Ensure a string is properly formatted as an RSA private key for OpenSSL
    def self.format_rsa_private_key(key)
      return key if key.is_a?(OpenSSL::PKey::RSA)
      raise ArgumentError, 'Invalid key type' unless key.is_a?(String)

      prefix = '-----BEGIN RSA PRIVATE KEY-----'
      postfix = '-----END RSA PRIVATE KEY-----'
      body_expression = /^(?:#{prefix})?\n?(.+?)\n?(?:#{postfix})?$/
      body = key.match(body_expression)[1]
      body = body.scan(/.{1,64}/).join("\n") unless body.include?("\n")

      "#{prefix}\n#{body}\n#{postfix}"
    end
  end
end
