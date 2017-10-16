class Api::V0::ChangesController < Api::V0::ApiController
  def index
    query = changes_collection
    sorting = sortation(params[:sort])
    paging = pagination(query)
    changes = query.limit(paging[:chunk_size]).offset(paging[:offset])
    changes = changes.order(sorting) unless sorting.nil?

    render json: {
      links: paging[:links],
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
    collection = Change
    collection = where_in_interval_param(collection, :priority)
    collection = where_in_interval_param(collection, :significance)
    collection
  end
end
