class Api::V0::DiffController < Api::V0::ApiController
  def show
    ensure_diffable

    render json: {
      links: {
        page: api_v0_page_url(change.version.page),
        from_version: api_v0_version_url(change.from_version),
        to_version: api_v0_version_url(change.version)
      },
      meta: {
        requested_type: params[:type]
      },
      data: raw_diff
    }
  end

  protected

  def raw_diff
    Differ.for_type!(params[:type]).diff(change, request.query_parameters)
  end

  def change
    @change ||= Change.find_by_api_id(params[:id])
  end

  def ensure_diffable
    from = change.from_version
    to = change.version

    error_details = []
    error_details << "version #{from.uuid}" if from.uri.blank?
    error_details << "version #{to.uuid}" if to.uri.blank?

    unless error_details.empty?
      raise Api::InputError,
        "Raw content is not available for #{error_details.join ' and '}"
    end
  end
end
