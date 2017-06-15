class ApplicationController < ActionController::Base
  include SameOriginSessionsConcern

  before_action :set_environment

  private

  def set_environment
    @env = Rails.env
  end
end
