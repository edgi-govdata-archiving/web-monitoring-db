class Api::V0::AnnotationsController < Api::V0::ApiController
  before_action :set_annotation, only: [:show]

  def index
    paging = pagination(parent_change.annotations)
    annotations = parent_change.annotations.limit(paging[:page_items]).offset(paging[:offset])

    render json: {
      links: paging[:links],
      data: annotations.as_json(include: { author: { only: [:id, :email] } })
    }
  end

  def show
    version = @annotation.change.version
    page = version.page
    render json: {
      links: {
        version: api_v0_page_version_url(page, version),
        from_version: api_v0_page_version_url(page, @annotation.change.from_version)
      },
      data: @annotation.as_json(include: { author: { only: [:id, :email] } })
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
    args.last[:change_id] =
      "#{parent_change.from_version.id}..#{parent_change.version.id}"
    api_v0_page_change_annotations_url(*args)
  end

  def set_annotation
    @annotation = Annotation.find(params[:id])
  end

  def parent_change
    @change ||= change_from_id(params[:change_id])
  end

  def change_from_id(change_id)
    return nil if params[:change_id].blank?

    if change_id.include?('..')
      from_id, to_id = change_id.split('..')
      if from_id.present?
        Change.between(from: Version.find(from_id), to: Version.find(to_id))
      else
        Version.find(to_id).change_from_previous ||
          (raise ActiveRecord::RecordNotFound, "There is no version prior to
            #{to_id} to change from.")
      end
    else
      Change.find(change_id)
    end
  end
end
