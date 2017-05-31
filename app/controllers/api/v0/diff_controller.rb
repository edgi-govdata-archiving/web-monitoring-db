class Api::V0::DiffController < Api::V0::ApiController
  def show
    if params[:type] != 'source'
      raise Api::NotImplementedError,
        "There is no registered differ for '#{params[:type]}'"
    end

    error_details = []
    error_details << "version #{change.from_version.uuid}" if change.from_version.uri.blank?
    error_details << "version #{change.version.uuid}" if change.version.uri.blank?
    unless error_details.empty?
      raise Api::InputError, "Raw content is not available for #{error_details.join ' and '}"
    end

    render json: {
      data: {
        page_id: change.version.page.uuid,
        version_id: change.version.uuid,
        from_version_id: change.from_version.uuid,
        diff_service: 'source',
        diff_service_version: '?',
        content: raw_diff
      }
    }
  end

  protected

  def raw_diff
    diff_format = params[:diff_format] || 'json'
    diff_service_url = ENV.fetch('DIFFER_SOURCE')
    response = HTTParty.get(diff_service_url, query: {
      a: change.from_version.uri,
      b: change.version.uri,
      format: diff_format
    })

    diff_format == 'json' ? JSON.parse(response.body) : response.body
  end

  def change
    unless @change
      Rails.logger.debug "FOUND #{params[:from_uuid]} : #{params[:to_uuid]}"
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
end
