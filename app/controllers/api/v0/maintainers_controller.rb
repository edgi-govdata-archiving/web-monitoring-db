class Api::V0::MaintainersController < Api::V0::ApiController
  include SortingConcern

  before_action(except: [:index, :show]) { authorize(:api, :annotate?) }

  def index
    query = maintainer_collection
    paging = pagination(query)
    maintainers = paging[:query]

    render json: {
      links: paging[:links],
      meta: paging[:meta],
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
    raise Api::ReadOnlyError if Rails.configuration.read_only

    data = JSON.parse(request.body.read)
    if data['uuid'].nil? && data['name'].nil?
      raise Api::InputError, 'You must specify either a `uuid` or `name` for the maintainer to add.'
    end

    valid_fields = ['name', 'parent_uuid']

    @maintainer =
      if page
        if data['uuid']
          page.add_maintainer(Maintainer.find(data['uuid']))
        else
          conditions = data.select {|key, _| valid_fields.include?(key)}
          begin
            maintainer = Maintainer.find_or_create_by(conditions)
          rescue ActiveRecord::RecordNotUnique
            raise Api::ResourceExistsError, "A different maintainer with the name `#{data['name']}` already exists."
          end
          page.add_maintainer(maintainer)
          maintainer
        end
      else
        conditions = data.select {|key, _| valid_fields.include?(key)}
        begin
          Maintainer.create!(conditions)
        rescue ActiveRecord::RecordNotUnique
          raise Api::ResourceExistsError, "A different maintainer with the name `#{data['name']}` already exists."
        end
      end

    show
  end

  def update
    raise Api::ReadOnlyError if Rails.configuration.read_only

    @maintainer = (page ? page.maintainers : Maintainer).find(params[:id])
    data = JSON.parse(request.body.read).slice('name', 'parent_id')
    @maintainer.update!(data)
    show
  end

  def destroy
    raise Api::ReadOnlyError if Rails.configuration.read_only

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

    collection = collection.order(created_at: :asc)
    sort_using_params(collection)
  end
end
