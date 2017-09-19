class Api::V0::DiffController < Api::V0::ApiController
  def show
    ensure_diffable

    content = raw_diff

    render json: {
      data: {
        page_id: change.version.page.uuid,
        from_version_id: change.from_version.uuid,
        to_version_id: change.version.uuid,
        diff_service: params[:type],
        diff_service_version: content.is_a?(Hash) && content['version'] || '?',
        content: content
      }
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
