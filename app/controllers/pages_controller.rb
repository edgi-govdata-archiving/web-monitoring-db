PAGE_SIZE = 500.0

class PagesController < ApplicationController
  def index
    @paging = pagination(VersionistaPage.all)
    @pages = VersionistaPage.order(updated_at: :desc).limit(PAGE_SIZE).offset(@paging[:offset])
    
    respond_to do |format|
      format.html
      format.json do
        render json: {
          links: @paging[:links],
          data: @pages
        }
      end
    end
  end
  
  def show
    @page = VersionistaPage.find(params[:id])
    respond_to do |format|
      format.html
      format.json do
        render json: {
          data: @page.as_json(include: :versions)
        }
      end
    end
  end
  
  protected
  
  # Undoubtedly there is a gem that makes this nicer
  def pagination(collection=nil)
    unless collection
      collection = @collection || VersionistaPage.all
    end
    
    format_type = request.format.to_sym
    total_items = collection.count
    total_pages = total_items == 0 ? 1 : (total_items / PAGE_SIZE).ceil
    page_number = (params[:page] || 1).to_i.clamp(1, total_pages)
    page_offset = (page_number - 1) * PAGE_SIZE
    
    links = {
      first: pages_path(nil, page: 1, format: format_type),
      last: pages_path(nil, page: total_pages, format: format_type),
      prev: nil,
      next: nil
    }
    if page_number > 1
      links[:prev] = pages_path(nil, page: page_number - 1, format: format_type)
    end
    if page_number < total_pages
      links[:next] = pages_path(nil, page: page_number + 1, format: format_type)
    end
    
    {
      pages: total_pages,
      page_number: page_number,
      offset: page_offset,
      total_items: total_items,
      page_items: PAGE_SIZE,
      links: links
    }
  end
end
