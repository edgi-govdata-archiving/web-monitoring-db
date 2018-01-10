class Api::V0::DiffController < Api::V0::ApiController
  def show
    ensure_diffable

    if stale?(etag: diff_etag, last_modified: diff_modification_time, public: true)
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

  def diff_modification_time
    [
      change.from_version.capture_time,
      change.version.capture_time,
      Differ.cache_date
    ].max
  end

  def cache_key
    "#{change.api_id}::#{diff_modification_time.iso8601}"
  end

  def diff_etag
    Digest::SHA256.hexdigest(cache_key)
  end
end
