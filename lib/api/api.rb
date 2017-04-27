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
end
