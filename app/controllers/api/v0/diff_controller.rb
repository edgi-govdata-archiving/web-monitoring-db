class Api::V0::DiffController < Api::V0::ApiController
  def show
    ensure_diffable

    # Cache harder in production. Mostly for proxies like CloudFront.
    cache_control = if Rails.env.development?
                      {}
                    else
                      {
                        max_age: params[:diff_version] ? 100.years : 1.day,
                        stale_while_revalidate: 7.days,
                        stale_if_error: 7.days
                      }
                    end

    when_stale(etag: diff_etag, last_modified: Differ.cache_date, public: true, cache_control:) do
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

  def change
    @change ||= Change.find_by_api_id(params[:id])
  end

  def ensure_diffable
    from = change.from_version
    to = change.version

    error_details = []
    error_details << "version #{from.uuid}" if from.body_url.blank? && from.network_error.blank?
    error_details << "version #{to.uuid}" if to.body_url.blank? && to.network_error.blank?

    unless error_details.empty?
      raise Api::InputError,
            "Raw content is not available for #{error_details.join ' and '}"
    end
  end

  def differ
    @differ ||= Differ.for_type!(params[:type])
  end

  def raw_diff
    differ.diff(change, **request.query_parameters)
  end

  def diff_etag
    cache_key = differ.cache_key(change, **request.query_parameters)
    Digest::SHA256.hexdigest(cache_key)
  end
end
