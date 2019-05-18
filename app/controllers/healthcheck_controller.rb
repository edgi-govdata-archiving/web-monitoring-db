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

    queues = 'ok'
    begin
      Resque.size(:not_a_real_queue_but_thats_ok)
    rescue StandardError => error
      queues = error.to_s
    end

    render json: { app: 'ok', db: db, queues: queues }
  end
end
