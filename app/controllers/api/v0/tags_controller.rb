class Api::V0::TagsController < Api::V0::ApiController
  def index
    query = tag_collection
    paging = pagination(query)
    tags = query.limit(paging[:chunk_size]).offset(paging[:offset])

    render json: {
      links: paging[:links],
      meta: { total_results: paging[:total_items] },
      data: tags
    }
  end

  def show
    @tag ||= Tag.find(params[:id])

    render json: {
      data: @tag
    }
  end

  protected

  def paging_path_for(model_type, *args)
    if page
      api_v0_page_tags_url(*args)
    else
      api_v0_tags_url(*args)
    end
  end

  def page
    return nil unless params.key? :page_id
    @page ||= Page.find(params[:page_id])
  end

  def tag_collection
    collection = page ? page.taggings.joins(:tag) : Tag
    collection.order(created_at: :asc)
  end
end
