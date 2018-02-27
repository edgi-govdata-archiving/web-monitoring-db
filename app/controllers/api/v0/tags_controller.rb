class Api::V0::TagsController < Api::V0::ApiController
  include SortingConcern

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

  def create
    data = JSON.parse(request.body.read)
    if data['uuid'].nil? && data['name'].nil?
      raise Api::InputError, 'You must specify either a `uuid` or `name` for the tag to add.'
    end

    @tag =
      if page
        if data['uuid']
          page.add_tag(Tag.find(data['uuid']))
        else
          page.add_tag(data['name'])
        end
      else
        Tag.find_or_create_by(name: data['name'])
      end
    show
  end

  def update
    @tag = (page ? page.tags : Tag).find(params[:id])
    data = JSON.parse(request.body.read)
    @tag.update(name: data['name'])
    show
  end

  def destroy
    # NOTE: this assumes you can only get here in the context of a page
    page.untag(Tag.find(params[:id]))
    redirect_to(api_v0_page_tags_url(page))
  end

  protected

  def paging_path_for(_model_type, *args)
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
    collection = collection.order(created_at: :asc)
    sort_using_params(collection)
  end
end
