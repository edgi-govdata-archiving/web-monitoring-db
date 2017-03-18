class Api::V1::AnnotationsController < Api::V1::ApiController
  before_action :set_annotation, only: [:show]

  def index
    paging = pagination(parent_change.annotations)
    annotations = parent_change.annotations.limit(paging[:page_items]).offset(paging[:offset])

    render json: {
      links: paging[:links],
      data: annotations.as_json(include: {author: {only: [:id, :email]}})
    }
  end

  def show
    version = @annotation.change.version
    page = version.page
    render json: {
      links: {
        change: api_v1_page_version_change_url(page, version, @annotation.change)
      },
      data: @annotation.as_json(include: {author: {only: [:id, :email]}})
    }
  end

  def create
    data = JSON.parse(request.body.read)
    @annotation = parent_change.annotate(data, current_user)
    parent_change.save

    if !@annotation.valid?
      render status: 500, json: {
        errors: @annotation.errors.full_messages.map do |message|
          {
            status: 500,
            title: message
          }
        end
      }
    else
      # TODO: should we also somehow return the change's `current_annotation`?
      self.show
    end
  end

  protected

  def paging_path_for_annotation(*args)
    args.last.merge!({change_id: parent_change.id})
    api_v1_page_version_change_annotations_path(*args)
  end

  def set_annotation
    @annotation = Annotation.find(params[:id])
  end

  def parent_change
    unless @change
      if params.has_key? :change_id
        @change = Change.find(params[:change_id])
      else
        @change = Version.find_by(uuid: params[:version_id], page_uuid: params[:page_id]).change_from_previous
      end
    end
    @change
  end
end
