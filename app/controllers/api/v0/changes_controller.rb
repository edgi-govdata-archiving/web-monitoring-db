class Api::V0::ChangesController < Api::V0::ApiController
  def index
    query = change_collection
    paging = pagination(query)
    changes = query.limit(paging[:page_items]).offset(paging[:offset])

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
    @change ||=
      if params[:id].include?('..')
        from_id, to_id = params[:id].split('..')
        if from_id.present?
          Change.between(from: Version.find(from_id), to: Version.find(to_id))
        else
          Version.find(to_id).change_from_previous ||
            (raise ActiveRecord::RecordNotFound, "There is no version prior to
              #{to_id} to change from.")
        end
      else
        Change.find(params[:id])
      end
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
    where_numeric_range_params(collection, :priority)
  end

  def where_numeric_range_params(collection, attribute)
    gt_param = :"#{attribute}_gt"
    gte_param = :"#{attribute}_gte"
    lt_param = :"#{attribute}_lt"
    lte_param = :"#{attribute}_lte"

    if params[gt_param]
      collection = collection.where("#{attribute} > ?", params[gt_param])
    elsif params[gte_param]
      collection = collection.where("#{attribute} >= ?", params[gte_param])
    end

    if params[lt_param]
      collection = collection.where("#{attribute} < ?", params[lt_param])
    elsif params[lte_param]
      collection = collection.where("#{attribute} <= ?", params[lte_param])
    end

    collection
  end
end
