module PagingConcern
  extend ActiveSupport::Concern

  DEFAULT_PAGE_SIZE = 100
  MAX_PAGE_SIZE = 10_000

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
    chunk_size = (params[:chunk_size] || DEFAULT_PAGE_SIZE).to_i.clamp(1, MAX_PAGE_SIZE)
    total_chunks = total_items.zero? ? 1 : (total_items / chunk_size.to_f).ceil
    chunk_number = (params[:chunk] || 1).to_i.clamp(1, total_chunks)
    item_offset = (chunk_number - 1) * chunk_size

    links = {
      first: path_resolver.call(
        collection_type,
        format: format_type,
        params: request.query_parameters.merge(chunk: 1)
      ),
      last: path_resolver.call(
        collection_type,
        format: format_type,
        params: request.query_parameters.merge(chunk: total_chunks)
      ),
      prev: nil,
      next: nil
    }
    if chunk_number > 1
      links[:prev] = path_resolver.call(
        collection_type,
        format: format_type,
        params: request.query_parameters.merge(chunk: chunk_number - 1,
                                               chunk_size: chunk_size)
      )
    end
    if chunk_number < total_chunks
      links[:next] = path_resolver.call(
        collection_type,
        format: format_type,
        params: request.query_parameters.merge(chunk: chunk_number + 1,
                                               chunk_size: chunk_size)
      )
    end

    {
      chunks: total_chunks,
      chunk_number: chunk_number,
      offset: item_offset,
      total_items: total_items,
      chunk_size: chunk_size,
      links: links
    }
  end
end
