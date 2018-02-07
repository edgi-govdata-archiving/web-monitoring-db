class Api::V0::PagesController < Api::V0::ApiController
  def index
    query = page_collection
    id_query = filter_maintainers_and_tags(query)
    paging = pagination(id_query)
    id_query = id_query.limit(paging[:chunk_size]).offset(paging[:offset])

    # NOTE: need to get :updated_at here because it's used for ordering
    page_ids = id_query.pluck(:uuid, :updated_at).collect {|data| data[0]}

    result_data =
      if should_include_versions
        results = query
          .where(uuid: page_ids)
          .includes(:versions)
          .order('versions.capture_time DESC')
        lightweight_query(results)
      elsif should_include_latest
        # Filters from the original query should *not* affect what's "latest",
        # (though they do affect which *pages* get included) so we build a
        # whole new query from scratch here.
        # NOTE: lightweight_query can't handle the series of N queries this
        # actually generates, but the result set is not as insanely huge as
        # when versions are included, so it's ok to just use ActiveRecord here.
        Page
          .where(uuid: page_ids)
          .order(updated_at: :desc)
          .includes(:latest, :maintainers, :tags)
          .as_json(include: [:latest, :maintainers, :tags])
      else
        # TODO: we could optimize and not do the page IDs check for this case
        # if we aren't also filtering by maintainers or tags.
        lightweight_query(query.where(uuid: page_ids))
      end

    render json: Oj.dump({
      links: paging[:links],
      meta: { total_results: paging[:total_items] },
      data: result_data
    }, mode: should_include_latest ? :rails : :strict)
  end

  def show
    page = Page.find(params[:id])
    render json: {
      data: page
    }, include: [:versions, :maintainers, :tags]
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
    # TODO: is there a query interface we can/should have for AND queries on
    # tags or maintainers? e.g. pages tagged 'home page' AND 'solar'
    # The query would be convoluted, but basically:
    # Page.joins(<<-SQL
    #   INNER JOIN (
    #     SELECT taggable_uuid as inner_t_uuid
    #       FROM taggings
    #       INNER JOIN tags ON taggings.tag_uuid = tags.uuid
    #       WHERE tags.name = 'home page' AND taggings.taggable_type = 'Page'
    #     INTERSECT
    #     SELECT taggable_uuid as inner_t_uuid
    #       FROM taggings
    #       INNER JOIN tags ON taggings.tag_uuid = tags.uuid
    #       WHERE tags.name = 'solar' AND taggings.taggable_type = 'Page'
    #   ) match_tags ON match_tags.inner_t_uuid = pages.uuid
    # SQL).all

    # TODO: remove agency and site here
    collection = Page.where(params.permit(:agency, :site, :title))
    # NOTE: You *can't* use left_outer_joins here because ActiveRecord screws
    # up and tries to join the tables *twice* in the query. I think this is
    # probably because it is a has_and_belongs_to_many, but have not had time
    # to break down exactly what is going wrong. In any case, `includes` works.
    collection = collection.eager_load(:maintainers, :tags)

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

  # Determine whether results should be limited to pages with certain
  # associations. Required because we still want the actual results to have all
  # the relevant associations for selected pages; the filters only change
  # which *pages* we select.
  def should_filter_by_associations
    params[:maintainers].is_a?(Array) || params[:tags].is_a?(Array)
  end

  # This is separate from the page_collection method because we want to make
  # sure this filtering is only used to select which *pages* are in the result;
  # we want actual output to include *all* the maintainers/tags on the pages
  # that were matched, not just the ones asked for.
  def filter_maintainers_and_tags(collection)
    if params[:maintainers].is_a?(Array)
      collection = collection.where(maintainers: { name: params[:maintainers] })
    end

    if params[:tags].is_a?(Array)
      collection = collection.where(tags: { name: params[:tags] })
    end

    collection
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
