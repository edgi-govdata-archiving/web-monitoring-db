class Api::V0::PagesController < Api::V0::ApiController
  def index
    query = page_collection
    paging = pagination(query)
    pages = query.limit(paging[:page_items]).offset(paging[:offset])

    # In order to handle pagination when querying across pages and versions
    # together, we do two separate queries:
    #   1. Get a unique list of page IDs according to our query conditions. We
    #      can use limit/offset here because the returned data is just pages,
    #      not unique combinations of page + version, so offset is actually an
    #      offset into the list of pages, which is what we want.
    #   2. Do a separate query to get all the actual data for the pages and
    #      versions associated with the page IDs found above in step 1.
    #
    # ActiveRecord normally does the above automatically, but adding ordering
    # based on associated records (e.g. versions.capture_time here) causes the
    # built-in behavior to break, so we do it manually here. For more, see:
    #   - https://github.com/edgi-govdata-archiving/web-monitoring-db/pull/129
    #   - https://github.com/rails/rails/issues/30531
    result_data =
      if should_include_versions
        # NOTE: need to get :updated_at here because it's used for ordering
        page_ids = pages.pluck(:uuid, :updated_at).collect {|data| data[0]}
        results = query
          .where(uuid: page_ids)
          .includes(:versions)
          .order('versions.capture_time')
        results.as_json(include: :versions)
      elsif should_include_latest
        pages.includes(:latest).as_json(include: :latest)
      else
        pages.as_json
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

  def should_include_latest
    !should_include_versions && boolean_param(:include_latest)
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
