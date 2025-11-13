# frozen_string_literal: true

module PagingConcern
  extend ActiveSupport::Concern

  DEFAULT_PAGE_SIZE = 100
  MAX_PAGE_SIZE = [ENV.fetch('MAX_COLLECTION_PAGE_SIZE', 10_000).to_i, 10].max

  protected

  def paging_path_for(model_type, *)
    self.send(:"paging_path_for_#{model_type}", *)
  end

  def paging_url_format
    request.format.to_sym
  end

  # Undoubtedly there is a gem that makes this nicer!
  # NOTE: this will load the paginated results for `collection`, so do this after you have completely
  # assembled your relation with all the relevant conditions.
  def pagination(collection, path_resolver: :paging_path_for, include_total: nil)
    collection ||= @collection
    path_resolver = method(path_resolver) if path_resolver.is_a? Symbol
    include_total = boolean_param(:include_total) if include_total.nil?

    chunk_size = (params[:chunk_size] || DEFAULT_PAGE_SIZE).to_i.clamp(1, MAX_PAGE_SIZE)
    total_items = include_total ? collection.size : nil
    chunk_number = (params[:chunk] || 1).to_i
    item_offset = (chunk_number - 1) * chunk_size

    query = collection.limit(chunk_size).offset(item_offset)
    # Use `length` instead of `count` or `size` to ensure we don't issue an expensive `count(x)` SQL query.
    is_last = query.length < chunk_size

    collection_type = collection.new.class.name.underscore.to_sym
    format_type = self.paging_url_format

    links = {
      first: path_resolver.call(
        collection_type,
        format: format_type,
        params: request.query_parameters.merge(chunk: 1,
                                               chunk_size:)
      ),
      last: nil,
      prev: nil,
      next: nil
    }

    if chunk_number > 1
      links[:prev] = path_resolver.call(
        collection_type,
        format: format_type,
        params: request.query_parameters.merge(chunk: chunk_number - 1,
                                               chunk_size:)
      )
    end

    if is_last
      links[:last] = request.url
    else
      links[:next] = path_resolver.call(
        collection_type,
        format: format_type,
        params: request.query_parameters.merge(chunk: chunk_number + 1,
                                               chunk_size:)
      )

      unless total_items.nil?
        total_chunks = total_items.zero? ? 1 : (total_items / chunk_size.to_f).ceil
        links[:last] = path_resolver.call(
          collection_type,
          format: format_type,
          params: request.query_parameters.merge(chunk: total_chunks,
                                                 chunk_size:)
        )
      end
    end

    {
      query:,
      links:,
      meta: include_total ? { total_results: total_items } : {},
      chunks: total_chunks,
      chunk_number:,
      offset: item_offset,
      total_items:,
      chunk_size:,
      is_last:
    }
  end
end
