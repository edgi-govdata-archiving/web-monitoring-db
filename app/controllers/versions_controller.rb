class VersionsController < ApplicationController
  include DeprecatedApiResources

  # For API requirements, we want a different response
  before_action :require_authentication!, only: [:annotate]

  def index
    # TODO: paging
    @versions = page.versions

    render json: {
      data: @versions.map {|version| version_resource_json(version)}
    }
  end

  def show
    @version = page.versions.find(params[:id])
    render json: {
      links: {
        page: page_url(@version.page, format: :json)
      },
      data: version_resource_json(@version)
    }
  end

  def annotations
    @version = page.versions.find(params[:id])
    render json: {
      links: {
        page: page_url(@version.page, format: :json),
        version: page_version_url(@version, format: :json)
      },
      data: @version.change_from_previous.annotations.map do |annotation|
        annotation_resource_json(annotation)
      end
    }
  end

  def annotate
    @version = page.versions.find(params[:id])
    @change = @version.change_from_previous

    annotation = JSON.parse(request.body.read)
    @change.annotate(annotation, current_user)
    @change.save

    self.show
  end

  protected

  def page
    Page.find(params[:page_id])
  end

  def require_authentication!
    unless user_signed_in?
      render json: {
        errors: [{ status: 401, title: 'You must be logged in to perform this action.' }]
      }
    end
  end
end
