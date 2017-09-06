class Api::V0::PagesController < Api::V0::ApiController
  def index
    query = page_collection
    paging = pagination(query)
    pages = query.limit(paging[:page_items]).offset(paging[:offset])

    # When using limit/offset on queries that `include` associations (e.g.
    # `versions` here), ActiveRecord actually does TWO queries:
    #   1. A query for only the IDs of the primary record type (e.g. pages).
    #      This ensures the limit/offset isn't mispositioned by extra rows
    #      created when joining to the versions table.
    #   2. A query for the joined primary and associated records (e.g. pages +
    #      versions) based on a list of primary record IDs from step 1 above.
    #      This gets us the actual data to instantiate models.
    #
    # HOWEVER! If ordering criteria includes fields from the associated records
    # (e.g. versions), then those fields have to be included in the first query,
    # which means we potentially get the wrong primary record IDs (since the
    # returned rows are now a pages + versions combo).
    #
    # To work around this, do a similar operation manually:
    #   1. Do NOT `includes(:versions)` and do NOT include version sorting on
    #      the first query where we get IDs so as not to trigger the two-query
    #      behavior (otherwise it would query for a set of IDs in order to query
    #      for the IDs we asked for).
    #   2. Once we have IDs, query specifically for those IDs and then include
    #      the associated version records and version ordering info. This does
    #      not trigger the two-query behavior because there's no limit/offset.
    #
    # NOTE: there was a previous solution to this that manually ordered
    # versions right here in Ruby. This approach results in the same number of
    # SQL queries and gets results already in the right order, so should
    # hopefully be more performant.
    result_data =
      if should_include_versions
        # NOTE: need to get :updated_at here because it's used for ordering
        page_ids = pages.pluck(:uuid, :updated_at).collect {|data| data[0]}
        results = query
          .where(uuid: page_ids)
          .includes(:versions)
          .order('versions.capture_time')
        results.as_json(include: :versions)
      else
        pages.includes(:latest).as_json(include: :latest)
      end

    render json: {
      links: paging[:links],
      data: result_data
    }
  end

  def show
    page = Page.find(params[:id])
    render json: {
      data: page.as_json(include: [:versions])
    }
  end

  protected

  def paging_path_for_page(*args)
    api_v0_pages_url(*args)
  end

  def should_include_versions
    boolean_param :include_versions
  end

  def page_collection
    collection = Page.where(params.permit(:agency, :site, :title))

    collection = where_in_range_param(
      collection,
      :capture_time,
      'versions.capture_time',
      &method(:parse_date!)
    )

    version_params = params.permit(:hash, :source_type)
    if version_params.present?
      collection = collection.joins(:versions).where(versions: {
        version_hash: params[:hash],
        source_type: params[:source_type]
      }.compact)
    end

    if params[:url]
      query = params[:url]
      if query.include? '*'
        query = query.gsub('%', '\%').gsub('_', '\_').tr('*', '%')
        collection = collection.where('url LIKE ?', query)
      else
        collection = collection.where(url: query)
      end
    end

    # If any queries create implicit joins, ensure we get a list of unique pages
    collection.distinct.order(updated_at: :desc)
  end
end
