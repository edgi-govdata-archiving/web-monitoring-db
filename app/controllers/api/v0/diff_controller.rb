class Api::V0::DiffController < Api::V0::ApiController
  def show
    ensure_diffable

    render json: {
      data: {
        page_id: change.version.page.uuid,
        from_version_id: change.from_version.uuid,
        to_version_id: change.version.uuid,
        diff_service: params[:type],
        diff_service_version: '?',
        content: raw_diff
      }
    }
  end

  protected

  def raw_diff
    Differ.for_type!(params[:type]).diff(change, request.query_parameters)
  end

  def change
    unless @change
      to_version = Version.find(params[:to_uuid] || params[:version_id])
      @change =
        if params[:from_uuid].present?
          Change.between(from: Version.find(params[:from_uuid]), to: to_version)
        else
          to_version.change_from_previous
        end
    end
    @change
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
