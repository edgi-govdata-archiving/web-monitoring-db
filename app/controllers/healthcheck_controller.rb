# frozen_string_literal: true

class HealthcheckController < ApplicationController
  def index
    # Succeed if the app is running, but provide additional
    # info if related components have gone down.
    db = 'ok'
    begin
      ActiveRecord::Base.connection.exec_query('SELECT 2 + 2;')
    rescue StandardError => error
      db = error.to_s
    end

    render json: { timestamp: Time.current.iso8601, app: 'ok', db: }
  end
end
