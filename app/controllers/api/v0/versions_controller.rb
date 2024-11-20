class Api::V0::VersionsController < Api::V0::ApiController
  include SortingConcern
  include BlockedParamsConcern

  SAMPLE_DAYS_DEFAULT = 183
  SAMPLE_DAYS_MAX = 365

  # Params that can cause expensive performance overhead require logging in.
  block_params_for_public_users actions: :all,
                                params: [:source_metadata, :status]
  block_params_for_public_users actions: [:index, :sampled],
                                params: [
                                  :include_change_from_previous,
                                  :include_change_from_earliest
                                ]

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
      prev: nil,
      page: api_v0_page_url(page)
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
    raise Api::ReadOnlyError if Rails.configuration.read_only

    authorize(:api, :import?)

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

  def paging_path_for_version(*)
    if @sampling
      api_v0_page_versions_sampled_url(*)
    elsif page
      api_v0_page_versions_url(*)
    else
      api_v0_versions_url(*)
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
    where_in_interval_param(collection, :status)
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

  # Our standard pagination is offset-based, which does not work well for large
  # tables like Versions, so we override the main pagination routine with a
  # versions-specific, range-based one here.
  # It might make sense to abstract this for use in other controllers/models.
  #
  # NOTE: this will load the paginated results for `collection`, so do this after you have completely
  # assembled your relation with all the relevant conditions.
  def pagination(collection, path_resolver: :paging_path_for, include_total: nil) # rubocop:disable Metrics/PerceivedComplexity,Metrics/CyclomaticComplexity
    collection ||= @collection
    path_resolver = method(path_resolver) if path_resolver.is_a? Symbol

    # The table is just too big to count! (Really, it can take a *long* time.)
    # If we need this back, it should only be allowed for logged-in users.
    include_total = boolean_param(:include_total) if include_total.nil?
    raise Api::InputError, '?include_total is not supported for versions' if include_total

    chunk_size = (params[:chunk_size] || PagingConcern::DEFAULT_PAGE_SIZE).to_i.clamp(1, PagingConcern::MAX_PAGE_SIZE)

    # `?chunk` should be "<timestamp>,<uuid>" or "<uuid>" (if the latter, we
    # need to look up the record to get the timestamp).
    start_point = params[:chunk]&.split(',')
    start_point = Version.find(start_point) if start_point&.length == 1

    sort_key = sorting_params&.first&.keys&.first || :capture_time
    sort_direction = sorting_params&.first&.values&.first || :asc

    query = collection
      .ordered(sort_key, point: start_point, direction: sort_direction)
      .limit(chunk_size)

    # Use `length` instead of `count` or `size` to ensure we don't issue an
    # expensive `count(x)` SQL query.
    is_last = query.length < chunk_size

    collection_type = collection.new.class.name.underscore.to_sym
    format_type = paging_url_format

    links = {
      first: path_resolver.call(
        collection_type,
        format: format_type,
        params: request.query_parameters.except(:chunk).merge(chunk_size:)
      ),
      next: nil
      # This does not currently support `last` and `prev` links. We *could*
      # solve each by issuing additional queries, but there's not a lot of
      # obvious value in doing so at the moment.
    }

    unless is_last
      last_record = query.last
      links[:next] = path_resolver.call(
        collection_type,
        format: format_type,
        params: request.query_parameters.merge(chunk: "#{last_record.capture_time.iso8601},#{last_record.uuid}",
                                               chunk_size:)
      )
    end

    links[:page] = api_v0_page_url(page) if page

    {
      query:,
      links:,
      meta: include_total ? { total_results: total_items } : {},
      # chunks: total_chunks,
      # chunk_number:,
      # offset: item_offset,
      # total_items:,
      chunk_size:,
      is_last:
    }
  end
end
