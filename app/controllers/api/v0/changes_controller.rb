class Api::V0::ChangesController < Api::V0::ApiController
  include SortingConcern

  def index
    query = changes_collection
    paging = pagination(query)
    changes = paging[:query]

    render json: {
      links: paging[:links],
      meta: paging[:meta],
      data: changes.as_json(methods: :current_annotation)
    }
  end

  def show
    render json: {
      links: {
        page: api_v0_page_url(page),
        from_version: api_v0_page_version_url(page, change.from_version),
        to_version: api_v0_page_version_url(page, change.version)
      },
      data: change.as_json(methods: :current_annotation)
    }
  end

  protected

  def page
    return nil unless params.key? :page_id

    @page ||= Page.find(params[:page_id])
  end

  def change
    @change ||= Change.find_by_api_id(params[:id])
  end

  def paging_path_for_change(*args)
    if change
      api_v0_page_change_url(*args)
    else
      api_v0_page_changes_url(*args)
    end
  end

  def changes_collection
    collection = page ? page.tracked_changes : Change
    collection = collection.order(created_at: :asc)
    collection = where_in_interval_param(collection, :priority)
    collection = where_in_interval_param(collection, :significance)
    sort_using_params(collection)
  end
end
