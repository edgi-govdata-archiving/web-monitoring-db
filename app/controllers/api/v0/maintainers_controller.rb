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
    parent_url = @maintainer.parent_uuid &&
                 api_v0_maintainer_url(@maintainer.parent_uuid)

    render json: {
      links: {
        parent: parent_url,
        children: api_v0_maintainers_url(params: { parent: @maintainer.uuid })
      },
      data: @maintainer
    }
  end

  def create
    data = JSON.parse(request.body.read)
    if data['uuid'].nil? && data['name'].nil?
      raise Api::InputError, 'You must specify either a `uuid` or `name` for the maintainer to add.'
    end

    @maintainer =
      if page
        if data['uuid']
          page.add_maintainer(Maintainer.find(data['uuid']))
        else
          maintainer = page.add_maintainer(data['name'])
          if data.key?('parent_uuid')
            maintainer.update!(parent_uuid: data['parent_uuid'])
          end
          maintainer
        end
      else
        maintainer = Maintainer.find_or_create_by(name: data['name'])
        if data.key?('parent_uuid')
          maintainer.update!(parent_uuid: data['parent_uuid'])
        end
        maintainer
      end
    show
  end

  def update
    @maintainer = (page ? page.maintainers : Maintainer).find(params[:id])
    data = JSON.parse(request.body.read).select do |key|
      ['name', 'parent_uuid'].include?(key)
    end
    @maintainer.update!(data)
    show
  end

  def destroy
    # NOTE: this assumes you can only get here in the context of a page
    page.remove_maintainer(Maintainer.find(params[:id]))
    redirect_to(api_v0_page_maintainers_url(page))
  end

  protected

  def paging_path_for(_model_type, *args)
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
      collection =
        if page
          collection.merge(Maintainer.where(parent_uuid: params[:parent]))
        else
          collection.where(parent_uuid: params[:parent])
        end
    end

    collection.order(created_at: :asc)
  end
end
