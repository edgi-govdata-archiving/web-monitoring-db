class Api::V0::VersionsController < Api::V0::ApiController
  def index
    query = version_collection
    paging = pagination(query)
    versions = query.limit(paging[:page_items]).offset(paging[:offset])

    render json: {
      links: paging[:links],
      data: versions.as_json(methods: :current_annotation)
    }
  end

  def show
    @version ||= page.versions.find(params[:id])
    render json: {
      links: {
        page: api_v0_page_url(@version.page),
        previous: @version.previous && api_v0_page_version_url(@version.page, @version.previous)
      },
      data: @version.as_json(methods: :current_annotation)
    }
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
      result = Archiver.archive(@version.uri)
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
    api_v0_page_versions_path(*args)
  end

  def page
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
      'source_metadata'
    ]
    params
      .require(:version)
      .select {|key| permitted_keys.include?(key)}
      .permit!
  end

  def version_collection
    collection = page.versions
    collection = collection.where(version_hash: params[:hash]) if params[:hash]

    capture_time = params[:capture_time]
    if capture_time
      if capture_time.include? '..'
        from, to = capture_time.split(/\.\.\.?/)
        if from.empty? && to.empty?
          raise Api::InputError, "Invalid date range: '#{capture_time}'"
        end
        if from.present?
          from = parse_date! from
          collection = collection.where('capture_time >= ?', from)
        end
        if to.present?
          to = parse_date! to
          collection = collection.where('capture_time <= ?', to)
        end
      else
        collection = collection.where(capture_time: parse_date!(capture_time))
      end
    end

    collection
  end

  def parse_date!(date)
    begin
      raise 'Nope' unless date.match?(/^\d{4}-\d\d-\d\d(T\d\d\:\d\d(\:\d\d(\.\d+)?)?(Z|([+\-]\d{4})))?$/)
      DateTime.parse date
    rescue
      raise Api::InputError, "Invalid date: '#{date}'"
    end
  end
end
