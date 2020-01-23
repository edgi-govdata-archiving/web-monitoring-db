class Api::V0::VersionsController < Api::V0::ApiController
  include SortingConcern

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

    if @version.uri.nil?
      raise Api::NotFoundError, "No raw content for #{@version.uuid}."
    elsif Archiver.external_archive_url?(@version.uri)
      redirect_to @version.uri, status: 301
    elsif Archiver.store.contains_url?(@version.uri)
      # Get the file
      filename = File.basename(@version.uri)
      upstream = Archiver.store.get_file(@version.uri)

      # Try to get the filetype, fall back on binary.
      type = version_media_type(@version) || 'application/octet-stream'
      # Set binary file disposition to attachment; anything else is inline.
      disposition = type == 'application/octet-stream' ? 'attachment' : 'inline'

      send_data(upstream, type: type, filename: filename, disposition: disposition)
    else
      raise Api::NotFoundError, "No raw content for #{@version.uuid}."
    end
  end

  def version_media_type(version)
    # Media type logic mostly cribbed from
    # web-monitoring-db/app/jobs/analyze_change_job.rb
    # Lines 176 to 180 in 658ae8c
    # TODO: this will eventually be a proper field on `version`:
    # https://github.com/edgi-govdata-archiving/web-monitoring-db/issues/199
    meta = version.source_metadata || {}
    media = meta['media_type'] || meta['content_type'] || meta['mime_type']
    if !media && meta['headers'].is_a?(Hash)
      media = meta['headers']['content-type'] || meta['headers']['Content-Type']
    end
    media
  end

  def create
    # TODO: unify this with import code in ImportVersionsJob#import_record
    @version = page.versions.new(version_params)

    if @version.uri.nil?
      if params[:content]
        # TODO: upload content
        raise Api::NotImplementedError, 'Raw content uploading not implemented yet.'
      end
    elsif !Archiver.already_archived?(@version.uri) || !@version.version_hash
      result = Archiver.archive(@version.uri, expected_hash: @version.version_hash)
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
    if page
      api_v0_page_versions_url(*args)
    else
      api_v0_versions_url(*args)
    end
  end

  def page
    return nil unless params.key? :page_id

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
      'source_metadata',
      'title'
    ]
    params
      .require(:version)
      .select {|key| permitted_keys.include?(key)}
      .permit!
  end

  def version_collection
    collection = page && page.versions || Version.order(created_at: :asc)

    if boolean_param(:different, default: true)
      collection = collection.where(different: true)
    end

    collection = collection.where({
      version_hash: params[:hash],
      source_type: params[:source_type]
    }.compact)

    if params[:source_metadata].respond_to?(:each)
      params[:source_metadata].each do |key, value|
        collection = collection.where('source_metadata->>? = ?', key, value)
      end
    end

    collection = where_in_range_param(collection, :capture_time, &method(:parse_date!))
    collection = where_in_interval_param(collection, :status)

    sort_using_params(collection)
  end

  def serialize_version(version, options = {})
    methods = options[:methods] || []
    methods << :change_from_previous if boolean_param(:include_change_from_previous)
    methods << :change_from_earliest if boolean_param(:include_change_from_earliest)
    options[:methods] = methods

    # Don't expose the backend URI, expose the 'raw' route instead.
    result = version.as_json(options)
    unless version.uri && Archiver.external_archive_url?(version.uri)
      result.update('uri' => raw_api_v0_version_url(version))
    end

    result
  end
end
