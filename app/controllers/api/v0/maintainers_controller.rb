class Api::V0::MaintainersController < Api::V0::ApiController
  def index
    query = maintainer_collection
    paging = pagination(query)
    maintainers = query.limit(paging[:chunk_size]).offset(paging[:offset])

    render json: {
      links: paging[:links],
      meta: { total_results: paging[:total_items] },
      data: maintainers
    }
  end

  def show
    @maintainer ||= Maintainer.find(params[:id])
    parent_url =
      if @maintainer.parent_uuid
        api_v0_maintainer_url(@maintainer.parent_uuid)
      else
        nil
      end

    render json: {
      links: {
        parent: parent_url,
        children: api_v0_maintainers_url(params: { parent: @maintainer.uuid }),
      },
      data: @maintainer
    }
  end

  protected

  def paging_path_for(model_type, *args)
    if page
      api_v0_page_maintainers_url(*args)
    else
      api_v0_maintainers_url(*args)
    end
  end

  def page
    return nil unless params.key? :page_id
    @page ||= Page.find(params[:page_id])
  end

  def maintainer_collection
    collection = page ? page.maintainerships.joins(:maintainer) : Maintainer

    if params.key?(:parent)
      if page
        collection = collection
          .merge(Maintainer.where(parent_uuid: params[:parent]))
      else
        collection = collection.where(parent_uuid: params[:parent])
      end
    end

    collection.order(created_at: :asc)
  end
end
