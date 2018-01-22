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
        lightweight_query(results)
      elsif should_include_latest
        pages.includes(:latest).as_json(include: [:agencies, :latest, :sites])
      else
        lightweight_query(pages)
      end

    render json: Oj.dump(
      {
        links: paging[:links],
        meta: { total_results: paging[:total_items] },
        data: result_data
      },
      mode: should_include_latest ? :rails : :strict
    )
  end

  def show
    page = Page
      .left_outer_joins(:agencies, :sites)
      .includes(:agencies, :sites)
      .find(params[:id])

    render json: {
      data: page
    }, include: [:versions, :agencies, :sites]
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
    # NOTE: You *can't* use left_outer_joins here because ActiveRecord screws
    # up and tries to join the tables *twice* in the query. I think this is
    # probably because it is a has_and_belongs_to_many, but have not had time
    # to break down exactly what is going wrong. In any case, `includes` works.
    collection = collection.includes(:agencies, :sites)

    collection = where_in_range_param(
      collection,
      :capture_time,
      'versions.capture_time',
      &method(:parse_date!)
    )

    version_params = params.permit(:hash, :source_type)
    if version_params.present?
      collection = collection.left_outer_joins(:versions).where(versions: {
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

  # Get the results of an ActiveRecord query as a simple JSON-compatible
  # structure without instantiating actual models. This is generally way
  # fancier footwork that one should be performing and should only be used for
  # extremely hot (in speed or memory) queries.
  #
  # It makes a number of assumptions about the structure of queries and only
  # works with some kinds of associations. Queries with associations that
  # require more than one actual SQL call are not supported. This is also
  # likely sensitive to underlying changes in ActiveRecord.
  def lightweight_query(relation)
    primary_type = relation.model
    # Hold information about associations in arrays indexed by the association
    # for later quick lookup when working with segments of each result row.
    associations = (relation.eager_load_values + relation.includes_values).collect(&:to_s)
    reflections = associations.collect {|association| primary_type._reflections.try(:[], association)}
    association_names = [nil] + associations
    types = [primary_type] + reflections.collect(&:klass)
    attribute_names = types.collect(&:attribute_names)

    # Ensure primary records are all consecutive and not interleaved because of
    # other orderings in the query.
    unless relation.order_values.frozen?
      relation.order_values.insert(
        0,
        "#{primary_type.table_name}.#{primary_type.primary_key} ASC"
      )
    end
    raw = ActiveRecord::Base.connection.exec_query(relation.to_sql)

    parsers = raw.columns.collect do |column|
      PrimitiveParser.for(raw.column_types[column])
    end

    # List of final resulting hashes for each primary model
    results = []
    # Hashes that map IDs to previously built objects for each association
    object_maps = association_names.collect {|_| {}}
    # A cached range for iterating throw associations on each row
    model_range = 0...association_names.count

    raw.rows.each do |row|
      primary_record = nil
      column_index = 0
      model_range.each do |model_index|
        model_id = row[column_index]
        record = object_maps[model_index][model_id]
        record_is_new = record.nil?

        # Create and read record data or skip ahead if we already have a copy
        if record
          column_index += attribute_names[model_index].count
        else
          record = {}
          object_maps[model_index][model_id] = record

          attribute_names[model_index].each do |name|
            value = row[column_index]
            parser = parsers[column_index]
            record[name] = parser ? parser.deserialize(value) : value
            column_index += 1
          end
        end

        # Add the record to the right association/list
        if model_index.zero?
          primary_record = record
          results << record if record_is_new
        elsif reflections[model_index - 1].is_a?(ActiveRecord::Reflection::HasOneReflection)
          field_name = association_names[model_index]
          primary_record[field_name] = record
        else
          field_name = association_names[model_index]
          field = (primary_record[field_name] ||= [])
          field << record unless model_id.nil? || field.include?(record)
        end
      end
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
