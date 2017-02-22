class PagesController < ApplicationController
  def index
    @pages = VersionistaPage.all
  end
  
  def show
    @page = VersionistaPage.find(params[:id])
  end
end
