# frozen_string_literal: true

class Api::V0::AnnotationsController < Api::V0::ApiController
  include SortingConcern
  include BlockedParamsConcern

  block_params_for_public_users params: [:include_total]
  before_action(only: [:create]) { authorize :api, :annotate? }
  before_action :set_annotation, only: [:show]

  def index
    annotations = sort_using_params(parent_change.annotations)
    paging = pagination(annotations)
    annotations = paging[:query]

    render json: {
      links: paging[:links],
      meta: paging[:meta],
      data: annotations.as_json(
        include: inclusions,
        except: :author_id
      )
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
        include: inclusions,
        except: :author_id
      )
    }
  end

  def create
    raise Api::ReadOnlyError if Rails.configuration.read_only

    begin
      data = JSON.parse(request.body.read)
    rescue JSON::ParserError
      raise Api::InputError, "Invalid JSON data: '#{request.body.read}'"
    end

    # TODO: it would be nice to handle this in annotation validation, but we
    # also want to prevent persisting a change that doesn't exist yet if the
    # annotation is invalid. Find a better way to do this if possible.
    raise Api::UnprocessableError, 'Annotations cannot be empty' if data.empty?

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

  def inclusions
    # Author info may be have e-mails; only allow other logged-in users to see.
    if current_user.present?
      { author: { only: [:id, :email] } }
    else
      {}
    end
  end
end
