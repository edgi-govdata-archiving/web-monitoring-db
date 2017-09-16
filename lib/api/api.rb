module Api
  class NotImplementedError < StandardError
    def status_code
      501
    end
  end

  class InputError < StandardError
    def status_code
      400
    end
  end

  class DynamicError < StandardError
    attr_accessor :status_code

    def initialize(message, status_code)
      @status_code = status_code
      super(message)
    end
  end
end
