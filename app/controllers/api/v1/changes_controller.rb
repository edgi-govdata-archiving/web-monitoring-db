class Api::V1::ChangesController < Api::V1::ApiController
  def index
    paging = pagination(version.tracked_changes)
    changes = version.tracked_changes.limit(paging[:page_items]).offset(paging[:offset])

    render json: {
      links: paging[:links],
      data: changes.as_json
    }
  end

  def show
    change = version.tracked_changes.find(params[:id])
    render json: {
      data: change.as_json
    }
  end

  protected

  def paging_path_for_change(*args)
    api_v1_page_version_changes_path(*args)
  end

  def version
    Version.find_by(uuid: params[:version_id], page_uuid: params[:page_id])
  end
end
