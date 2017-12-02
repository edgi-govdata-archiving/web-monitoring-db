class Api::V0::AnnotationsController < Api::V0::ApiController
  before_action :set_annotation, only: [:show]

  def index
    paging = pagination(parent_change.annotations)
    annotations = parent_change.annotations.limit(paging[:chunk_size]).offset(paging[:offset])

    render json: {
      links: paging[:links],
      data: annotations.as_json(
        include: { author: { only: [:id, :email] } },
        except: :author_id
      ),
      meta: { total_results: paging[:total_items] }
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
      data: @annotation.as_json(
        include: { author: { only: [:id, :email] } },
        except: :author_id
      )
    }
  end

  def create
    data = JSON.parse(request.body.read)
    @annotation = parent_change.annotate(data, current_user)
    parent_change.save!
    # TODO: should we also somehow return the change's `current_annotation`?
    show
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
    @change ||= Change.find_by_api_id(params[:change_id])
  end
end
