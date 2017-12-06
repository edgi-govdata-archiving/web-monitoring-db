class Api::V0::PagesController < Api::V0::ApiController
  def index
    query = page_collection
    paging = pagination(query)
    pages = query.limit(paging[:chunk_size]).offset(paging[:offset])

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
          .order('versions.capture_time DESC')
        lightweight_query(results, :versions)
      elsif should_include_latest
        # [pages.includes(:latest), :latest]
        page_ids = pages.pluck(:uuid, :updated_at).collect {|data| data[0]}
        results = Page
          .where(uuid: page_ids)
          .includes(:latest)
        lightweight_query(results, :latest)
      else
        lightweight_query(pages)
      end

    render json: Oj.dump({
      links: paging[:links],
      meta: { total_results: paging[:total_items] },
      data: result_data
    }, mode: :strict)
  end

  def show
    page = Page.find(params[:id])
    render json: {
      data: page
    }, include: [:versions]
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

  # Get the results of an ActiveRecord query (and, optionally, one association)
  # as a simple JSON-compatible structure without instantiating actual models.
  # This is generally way fancier footwork that one should be performing and
  # should only be used for extremely hot (in speed or memory) queries.
  #
  # It makes a number of assumptions about the structure of queries and only
  # works with has_many and has_one associations (the association can also be
  # nil). Those assumptions are generally reasonable, but are likely sensitive
  # to underlying changes in ActiveRecord.
  def lightweight_query(relation, association = nil)
    reflection = relation.model._reflections.try(:[], association.to_s)

    if !reflection || reflection.is_a?(ActiveRecord::Reflection::HasManyReflection)
      lightweight_query_with_many(relation, reflection)
    elsif reflection.is_a?(ActiveRecord::Reflection::HasOneReflection)
      lightweight_query_with_one(relation, reflection)
    else
      raise StandardError, "lightweight query can only handle `has_one` and `has_many` associations, not #{reflection.class.name}"
    end
  end

  # Perform a lightweight query with a has_many association (or no association)
  def lightweight_query_with_many(relation, association_reflection)
    primary_type = relation.model
    names = primary_type.attribute_names
    primary_names_length = names.length
    association = association_reflection.try(:name)
    names += association_reflection.klass.attribute_names if association_reflection

    # Ensure primary records are all consecutive and not interleaved because of
    # other orderings in the query.
    relation.order_values.insert(
      0,
      "#{primary_type.table_name}.#{primary_type.primary_key} ASC"
    )
    raw = ActiveRecord::Base.connection.exec_query(relation.to_sql)

    skip_length = raw.columns.find_index('t0_r0') || 0
    primary_names_length += skip_length
    names = (0...skip_length).to_a + names

    parsers = raw.columns.collect do |column|
      PrimitiveParser.for(raw.column_types[column])
    end

    last_id = nil
    current_record = nil
    results = []

    raw.rows.each do |row|
      if last_id != row[0]
        current_record = {}
        results << current_record
        current_record[association] = [] if association
      end

      associated_record = {}

      row.each_with_index do |value, index|
        next if index < skip_length
        next if index < primary_names_length && last_id == row[0]
        target = index < primary_names_length ? current_record : associated_record
        parser = parsers[index]

        target[names[index]] = parser ? parser.deserialize(value) : value
      end

      current_record[association] << associated_record if association
      last_id = row[0]
    end

    results
  end

  # Perform a lightweight query with a has_one association
  def lightweight_query_with_one(relation, association_reflection)
    raw = ActiveRecord::Base.connection.exec_query(relation.to_sql)
    primary_type = relation.model
    names = primary_type.attribute_names
    names_length = names.length

    parsers = raw.columns.collect do |column|
      PrimitiveParser.for(raw.column_types[column])
    end

    last_id = nil
    results = []
    id_map = {}

    raw.rows.each do |row|
      next if last_id == row[0]

      record = {}
      results << record
      last_id = row[0]
      id_map[last_id] = record

      row.each_with_index do |value, index|
        next if index >= names_length
        parser = parsers[index]

        record[names[index]] = parser ? parser.deserialize(value) : value
      end
    end

    # And now for the association
    secondary_type = association_reflection.klass
    secondary_query = secondary_type.where(
      association_reflection.foreign_key => id_map.keys
    )
    if association_reflection.scope
      secondary_query = secondary_query.merge(association_reflection.scope)
    end
    raw = ActiveRecord::Base.connection.exec_query(secondary_query.to_sql)
    names = secondary_type.attribute_names
    names_length = names.length

    parsers = raw.columns.collect do |column|
      PrimitiveParser.for(raw.column_types[column])
    end

    last_id = nil
    raw.rows.each do |row|
      next if last_id == row[0]

      record = {}
      last_id = row[0]

      row.each_with_index do |value, index|
        next if index >= names_length
        parser = parsers[index]

        record[names[index]] = parser ? parser.deserialize(value) : value
        if record[names[index]].is_a? Time
          record[names[index]] = record[names[index]].iso8601
        end
      end

      id_map[record[association_reflection.foreign_key]][association_reflection.name] = record
    end

    results
  end

  # A simple wrapper for parsing data from the DB into a primitive,
  # JSON-compatible type. Given a DB parser, it will deserialize with that
  # parser and then further parse to a primitive.
  class PrimitiveParser
    def self.for(parser)
      if parser.class.name.ends_with?('::DateTime')
        new(parser)
      elsif parser.class.name.starts_with?('ActiveRecord::ConnectionAdapters')
        parser
      end
    end

    def initialize(parser)
      @parser = parser
    end

    def deserialize(value)
      result = @parser.deserialize(value)
      result.is_a?(Time) ? result.iso8601 : result
    end
  end
end
