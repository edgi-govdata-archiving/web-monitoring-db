class HealthcheckController < ApplicationController
  def index
    # Ensure database is available
    ActiveRecord::Base.connection.exec_query('SELECT 2 + 2;')
    # Ensure job queue is available
    Resque.size(:not_a_real_queue_but_thats_ok)
    render json: {}
  end
end
