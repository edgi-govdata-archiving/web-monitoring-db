class Api::V0::VersionsController < Api::V0::ApiController
  include SortingConcern

  SAMPLE_DAYS_DEFAULT = 183
  SAMPLE_DAYS_MAX = 365

  def index
    query = version_collection
    paging = pagination(query)
    versions = paging[:query]

    render json: {
      links: paging[:links],
      meta: paging[:meta],
      data: versions.collect {|version| serialize_version(version)}
    }
  end

  def sampled
    @sampling = true
    raise API::NotFoundError('You must provide a page to sample versions of.') unless page

    # TODO: support variable sample periods? Need to figure out a reference
    # point for when those periods start.
    # We don't support the complex filters and options #index does; we want to
    # keep this as simple and fast as possible.
    time_range = parse_sample_range
    query = page.versions.where_in_unbounded_range(:capture_time, time_range)

    samples = query.each_with_object({}) do |version, result|
      key = version.capture_time.to_date.iso8601
      if result.key?(key)
        result[key][:version_count] += 1
        if version.different && !result[key][:version].different
          result[key][:version] = version
        end
      else
        result[key] = {
          time: key,
          version_count: 1,
          version:
        }
      end
    end

    samples.each_value do |sample|
      sample[:version] = serialize_version(sample[:version])
    end

    next_version = page.versions.where('capture_time < ?', time_range[0]).select(:uuid, :capture_time).first
    if samples.empty? && next_version.nil?
      raise Api::NotFoundError, '`to` time is older than the oldest version'
    end

    links = {
      first: api_v0_page_versions_sampled_url(page),
      last: nil,
      next: nil,
      prev: nil
    }
    # Optimize forward pagination by skipping to a time range with data.
    if next_version
      next_to = next_version.capture_time.to_date + 1.day
      links[:next] = api_v0_page_versions_sampled_url(
        page,
        params: { capture_time: "#{(next_to - SAMPLE_DAYS_DEFAULT.days).iso8601}..#{next_to.iso8601}" }
      )
    end
    if time_range[1] < Time.now
      links[:prev] = api_v0_page_versions_sampled_url(
        page,
        params: { capture_time: "#{time_range[1].iso8601}..#{(time_range[1] + SAMPLE_DAYS_DEFAULT.days).iso8601}" }
      )
    end

    render json: {
      links:,
      meta: {
        sample_period: 'day',
        warning: 'This API endpoint is experimental and may change'
      },
      data: samples.values
    }
  end

  def show
    @version ||= version_collection.find(params[:id])
    render json: {
      links: {
        page: api_v0_page_url(@version.page),
        previous: @version.previous && api_v0_version_url(@version.previous),
        next: @version.next && api_v0_version_url(@version.next)
      },
      data: serialize_version(@version)
    }
  end

  def raw
    @version ||= version_collection.find(params[:id])

    expires_in 1.year, public: true

    if @version.body_url.nil?
      raise Api::NotFoundError, "No raw content for #{@version.uuid}."
    elsif Archiver.external_archive_url?(@version.body_url)
      redirect_to @version.body_url, status: 301, allow_other_host: true
    elsif Archiver.store.contains_url?(@version.body_url)
      # Get the file
      filename = File.basename(@version.body_url)
      upstream = Archiver.store.get_file(@version.body_url)

      # Try to get the filetype, fall back on binary.
      type = @version.media_type || 'application/octet-stream'
      # Set binary file disposition to attachment; anything else is inline.
      disposition = type == 'application/octet-stream' ? 'attachment' : 'inline'

      send_data(upstream, type:, filename:, disposition:)
    else
      raise Api::NotFoundError, "Cannot serve raw content for #{@version.uuid}."
    end
  end

  def create
    # TODO: unify this with import code in ImportVersionsJob#import_record
    @version = page.versions.new(version_params)

    if @version.body_url.nil?
      if params[:content]
        # TODO: upload content
        raise Api::NotImplementedError, 'Raw content uploading not implemented yet.'
      end
    elsif !Archiver.already_archived?(@version.body_url) || !@version.body_hash
      result = Archiver.archive(@version.body_url, expected_hash: @version.body_hash)
      @version.body_hash = result[:hash]
      @version.body_url = result[:url]
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
    if @sampling
      api_v0_page_versions_sampled_url(*args)
    elsif page
      api_v0_page_versions_url(*args)
    else
      api_v0_versions_url(*args)
    end
  end

  def page
    return nil unless params.key? :page_id

    @page ||= Page.find(params[:page_id])
  end

  def parse_sample_range
    time_range = parse_unbounded_range!(params[:capture_time], 'capture_time') { |d| parse_date!(d).to_date } || []

    if time_range[0] && time_range[1]
      time_range[1] = time_range[1] + 1.day
      if time_range[1] - time_range[0] > SAMPLE_DAYS_MAX.days
        raise Api::InputError, "time range must be no more than #{SAMPLE_DAYS_MAX} days"
      end
    elsif time_range[1]
      to_time = time_range[1] + 1.day
      time_range = [to_time - SAMPLE_DAYS_DEFAULT.days, to_time]
    elsif time_range[0]
      from_time = time_range[0]
      time_range = [from_time, from_time + SAMPLE_DAYS_DEFAULT.days]
    else
      to_time = Date.today + 1.day
      time_range = [to_time - SAMPLE_DAYS_DEFAULT.days, to_time]
    end

    time_range
  end

  def version_params
    # Use select instead of `permit` to get the metadata blob. (It's freeform,
    # so we don't know what keys will be in it.)
    permitted_keys = [
      'uuid',
      'capture_time',
      'body_url',
      'body_hash',
      'source_type',
      'source_metadata',
      'title'
    ]
    params
      .require(:version)
      .select {|key| permitted_keys.include?(key)}
      .permit!
  end

  def version_collection
    collection = (page && page.versions) || Version.order(created_at: :asc)

    if boolean_param(:different, default: true)
      collection = collection.where(different: true)
    end

    collection = collection.where({
      body_hash: params[:hash],
      source_type: params[:source_type]
    }.compact)

    if params[:source_metadata].respond_to?(:each)
      params[:source_metadata].each do |key, value|
        collection = collection.where('source_metadata->>? = ?', key, value)
      end
    end

    collection = where_in_range_param(collection, :capture_time) { |d| parse_date!(d) }
    collection = where_in_interval_param(collection, :status)

    sort_using_params(collection)
  end

  def serialize_version(version, options = {})
    methods = options[:methods] || []
    methods << :change_from_previous if boolean_param(:include_change_from_previous)
    methods << :change_from_earliest if boolean_param(:include_change_from_earliest)
    options[:methods] = methods

    # Don't expose the backend `body_url`, expose the 'raw' route instead.
    result = version.as_json(options)
    unless version.body_url && Archiver.external_archive_url?(version.body_url)
      result.update('body_url' => raw_api_v0_version_url(version))
    end

    result
  end
end
