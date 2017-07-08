class Api::V0::PagesController < Api::V0::ApiController
  def index
    query = page_collection
    paging = pagination(query)
    pages = query.order(updated_at: :desc).limit(paging[:page_items]).offset(paging[:offset])

    json_options = {
      include: should_include_versions ? :versions : :latest
    }

    render json: {
      links: paging[:links],
      data: pages.as_json(json_options)
    }
  end

  def show
    page = Page.find(params[:id])
    render json: {
      data: page.as_json(include: { versions: { methods: :current_annotation } })
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

    collection =
      if should_include_versions
        collection.includes(:versions).order('versions.capture_time')
      else
        collection.includes(:latest)
      end

    # If any queries create implicit joins, ensure we get a list of unique pages
    collection.distinct
  end
end
