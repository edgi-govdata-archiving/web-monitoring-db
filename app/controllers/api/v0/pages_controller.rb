class Api::V0::PagesController < Api::V0::ApiController
  def index
    query = page_collection
    paging = pagination(query)
    pages = query.order(updated_at: :desc).limit(paging[:page_items]).offset(paging[:offset])

    render json: {
      links: paging[:links],
      data: pages
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
    api_v0_pages_path(*args)
  end

  def page_collection
    collection = Page.all
    collection = filter_param(collection, :site)
    collection = filter_param(collection, :agency)

    if params[:url]
      query = params[:url]
      if query.include? '*'
        query = query.gsub('%', '\%').gsub('_', '\_').tr('*', '%')
        collection = collection.where('url LIKE ?', query)
      else
        collection = collection.where(url: query)
      end
    end

    capture_time = params[:capture_time]
    if capture_time
      if capture_time.include? '..'
        from, to = capture_time.split(/\.\.\.?/)
        if from.empty? && to.empty?
          raise Api::InputError, "Invalid date range: '#{capture_time}'"
        end

        with_versions = collection.joins(:versions)
        if from.present?
          from = parse_date! from
          collection = with_versions.where('versions.capture_time >= ?', from)
        end
        if to.present?
          to = parse_date! to
          collection = with_versions.where('versions.capture_time <= ?', to)
        end
      else
        collection = with_versions.where(versions: {
          capture_time: parse_date!(capture_time)
        })
      end
    end

    collection
  end
end
