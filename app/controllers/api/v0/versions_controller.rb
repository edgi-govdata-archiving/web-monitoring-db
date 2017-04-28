class Api::V0::VersionsController < Api::V0::ApiController
  def index
    paging = pagination(page.versions)
    versions = page.versions.limit(paging[:page_items]).offset(paging[:offset])

    render json: {
      links: paging[:links],
      data: versions.as_json(methods: :current_annotation)
    }
  end

  def show
    @version ||= page.versions.find(params[:id])
    render json: {
      links: {
        page: api_v0_page_url(@version.page),
        previous: api_v0_page_version_url(@version.page, @version.previous)
      },
      data: @version.as_json(methods: :current_annotation)
    }
  end

  def create
    @version = page.versions.new(version_params)

    if @version.uri.nil?
      if params[:content]
        # TODO: upload content
        raise Api::NotImplementedError, 'Raw content uploading not implemented yet.'
      else
        raise Api::InputError, 'You must include raw version content in the `content` field if you do not provide a URI.'
      end
    elsif !Archiver.already_archived?(@version.uri) || !@version.version_hash
      result = Archiver.archive(@version.uri)
      @version.version_hash = result[:hash]
      @version.uri = result[:url]
    end

    @version.validate!

    existing = page.versions.where(
      capture_time: @version.capture_time,
      source_type: @version.source_type
    ).first

    if existing
      redirect_to api_v0_page_version_url(existing.page, existing)
    else
      @version.save
      show
    end
  end

  protected

  def paging_path_for_version(*args)
    api_v0_page_versions_path(*args)
  end

  def page
    @page ||= Page.find(params[:page_id])
  end

  def version_params
    # Use select instead of `permit` to get the metadata blob. (It's freeform,
    # so we don't know what keys will be in it.)
    permitted_keys = [
      'uuid',
      'capture_time',
      'uri',
      'version_hash',
      'source_type',
      'source_metadata'
    ]
    params
      .require(:version)
      .select {|key| permitted_keys.include?(key)}
      .permit!
  end
end
