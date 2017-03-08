class VersionsController < ApplicationController
  # For API requirements, we want a different response
  before_action :require_authentication!, only: [:annotate]

  def index
    # TODO: paging
    @versions = page.versions

    render json: {
      data: @versions
    }
  end

  def show
    @version = page.versions.find(params[:id])
    render json: {
      links: {
        page: page_url(@version.page, format: :json)
      },
      data: @version
    }
  end

  def annotations
    @version = page.versions.find(params[:id])
    render json: {
      links: {
        page: page_url(@version.page, format: :json),
        version: page_version_url(@version, format: :json)
      },
      data: @version.annotations
    }
  end

  def annotate
    @version = page.versions.find(params[:id])

    annotation = JSON.parse(request.body.read)
    @version.annotate(annotation)
    @version.save

    self.show
  end

  protected

  def page
    VersionistaPage.find(params[:page_id])
  end

  def require_authentication!
    unless user_signed_in?
      render json: {
        errors: [{status: 401, title: 'You must be logged in to perform this action.'}]
      }
    end
  end
end
