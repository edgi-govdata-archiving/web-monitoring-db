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
    @change ||=
      if params[:id].include?('..')
        from_id, to_id = params[:id].split('..')
        if from_id.present?
          Change.between(from: Version.find(from_id), to: Version.find(to_id))
        else
          Version.find(to_id).change_from_previous ||
            (raise ActiveRecord::RecordNotFound, "There is no version prior to
              #{to_id} to change from.")
        end
      else
        Change.find(params[:id])
      end
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
