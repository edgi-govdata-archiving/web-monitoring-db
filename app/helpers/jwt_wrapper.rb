module JWTWrapper
  def self.private_key=(new_key)
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

    expire_at = payload[:exp] || Time.now + expire_after

    payload = payload.dup
    payload[:exp] = expire_at.to_i

    JWT.encode(payload, @private_key, 'RS256')
  end

  def self.decode(token)
    raise 'You must set a private key for tokens in order to use JWTs' unless @private_key

    begin
      # TODO: raise up expiration errors so we can return a special response?
      decoded = JWT.decode(token, @public_key, true, algorithm: 'RS256')
      decoded.first
    rescue
      nil
    end
  end
end
