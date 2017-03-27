class Api::V0::ApiController < ApplicationController
  include PagingConcern
  before_action :require_authentication!, only: [:create]

  protected

  def paging_url_format
    ''
  end

  def require_authentication!
    unless user_signed_in?
      render status: 401, json: {
        errors: [{
          status: 401,
          title: 'You must be logged in to perform this action.'
        }]
      }
    end
  end
end
