module PagingConcern
  extend ActiveSupport::Concern

  PAGE_SIZE = 100

  protected

  def paging_path_for(model_type, *args)
    self.send "paging_path_for_#{model_type}", *args
  end

  def paging_url_format
    request.format.to_sym
  end

  # Undoubtedly there is a gem that makes this nicer
  def pagination(collection, path_resolver: :paging_path_for, url_format: nil)
    unless collection
      collection = @collection
    end

    collection_type = collection.new.class.name.underscore.to_sym

    if path_resolver.is_a? Symbol
      resolver_symbol = path_resolver
      path_resolver = lambda {|*args| self.send resolver_symbol, *args}
    end

    format_type = url_format || self.paging_url_format
    total_items = collection.count
    total_pages = total_items.zero? ? 1 : (total_items / PAGE_SIZE.to_f).ceil
    page_number = (params[:page] || 1).to_i.clamp(1, total_pages)
    page_offset = (page_number - 1) * PAGE_SIZE

    links = {
      first: path_resolver.call(collection_type, page: 1, format: format_type),
      last: path_resolver.call(collection_type, page: total_pages, format: format_type),
      prev: nil,
      next: nil
    }
    if page_number > 1
      links[:prev] = path_resolver.call(collection_type, page: page_number - 1, format: format_type)
    end
    if page_number < total_pages
      links[:next] = path_resolver.call(collection_type, page: page_number + 1, format: format_type)
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
