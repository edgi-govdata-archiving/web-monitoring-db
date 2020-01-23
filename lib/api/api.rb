module Api
  class ApiError < StandardError
  end

  class NotImplementedError < ApiError
    def status_code
      501
    end
  end

  class InputError < ApiError
    def status_code
      400
    end
  end

  class DynamicError < ApiError
    attr_accessor :status_code

    def initialize(message, status_code)
      @status_code = status_code
      super(message)
    end
  end

  class AuthorizationError < ApiError
    def status_code
      401
    end
  end

  class ForbiddenError < ApiError
    def status_code
      403
    end
  end

  class NotFoundError < ApiError
    def status_code
      404
    end
  end

  class ResourceExistsError < ApiError
    def status_code
      409
    end
  end

  class UnprocessableError < ApiError
    def status_code
      422
    end
  end

  class MismatchedHashError < ApiError
    def status_code
      502
    end

    def initialize(url, hash)
      super("Response body for '#{url}' did not match expected hash (#{hash})")
    end
  end
end
