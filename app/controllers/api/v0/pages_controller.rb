class Api::V0::PagesController < Api::V0::ApiController
  def index
    paging = pagination(Page.all)
    pages = Page.order(updated_at: :desc).limit(paging[:page_items]).offset(paging[:offset])

    render json: {
      links: paging[:links],
      data: pages
    }
  end

  def show
    page = Page.find(params[:id])
    render json: {
      data: page.as_json(include: {versions: {methods: :current_annotation}})
    }
  end

  protected

  def paging_path_for_page(*args)
    api_v1_pages_path(*args)
  end
end
