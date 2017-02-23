PAGE_GROUP_SIZE = 500.0

class PagesController < ApplicationController
  def index
    # TODO: gem for paging?
    @total_pages = VersionistaPage.all.count
    @total_page_groups = if @total_pages == 0
      1
    else
      (@total_pages / PAGE_GROUP_SIZE).ceil
    end
    @page_group_number = (params[:page] || 1).to_i.clamp(1, @total_page_groups)
    
    offset = (@page_group_number - 1) * PAGE_GROUP_SIZE
    @pages = VersionistaPage.order(updated_at: :desc).limit(PAGE_GROUP_SIZE).offset(offset)
  end
  
  def show
    @page = VersionistaPage.find(params[:id])
  end
end
