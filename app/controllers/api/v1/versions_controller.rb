class Api::V1::VersionsController < Api::V1::ApiController
  def index
    page = Page.find(params[:page_id])
    paging = pagination(page.versions)
    versions = page.versions.limit(paging[:page_items]).offset(paging[:offset])

    render json: {
      links: paging[:links],
      data: versions.as_json(methods: :current_annotation)
    }
  end

  def show
    page = Page.find(params[:page_id])
    version = page.versions.find(params[:id])
    render json: {
      links: {
        page: api_v1_page_url(version.page)
      },
      data: version.as_json(methods: :current_annotation)
    }
  end

  protected

  def paging_path_for_version(*args)
    api_v1_page_versions_path(*args)
  end
end
