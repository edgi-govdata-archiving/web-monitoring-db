class Api::V0::PagesController < Api::V0::ApiController
  include SortingConcern
  include BlockedParamsConcern

  # Params that can cause expensive performance overhead require logging in.
  block_params_for_public_users actions: [:index],
                                params: [
                                  :include_earliest,
                                  :include_latest
                                ]

  def index
    query = page_collection
    id_query = filter_maintainers_and_tags(query)
    paging = pagination(id_query)
    id_query = paging[:query]

    # NOTE: need to get :updated_at here because it's used for ordering
    # We've already applied the actual sorting in page_collection.
    order_attributes =
      if sorting_params.present?
        sorting_params.collect {|sorting| sorting.keys.first}
      else
        [:updated_at]
      end
    page_ids = id_query.pluck(:uuid, *order_attributes).collect {|data| data[0]}

    oj_mode = :strict
    result_data =
      if !should_allow_versions && should_include_versions
        raise Api::NotImplementedError, 'The ?include_versions query argument has been disabled.'
      elsif should_allow_versions && should_include_versions
        oj_mode = :rails
        # Including versions, tags, and maintainers is perfectly OK, but
        # when you add the WHERE clause for versions, ActiveRecord issues
        # one extra query per page for the tags and maintainers. Instead,
        # issue two separate queries and manually plug them together.
        results = Page
          .where(uuid: page_ids)
          .includes(:versions)
          .order(sorting_params.present? ? sorting_params : 'pages.updated_at DESC')
          .order('versions.capture_time DESC')
          .as_json(include: :versions)
        # Tags and Maintainers
        additions = Page
          .where(uuid: page_ids)
          .includes(:tags, :maintainers)
          .order(sorting_params.present? ? sorting_params : 'pages.updated_at DESC')
          .index_by(&:uuid)
        # Join them up!
        results.each do |page|
          other_page = additions[page['uuid']]
          page['tags'] = other_page.taggings.as_json
          page['maintainers'] = other_page.maintainerships.as_json
        end

        results
      else
        # Filters from the original query should *not* affect what's "latest"
        # or "earliest" (though they do affect which *pages* get included), so
        # we build a whole new query from scratch here.
        oj_mode = :rails
        relations = [:maintainers, :tags]
        relations << :earliest if should_include_earliest
        relations << :latest if should_include_latest
        Page
          .where(uuid: page_ids)
          .order(sorting_params.present? ? sorting_params : 'updated_at DESC')
          .includes(*relations)
          .as_json(include: relations)
      end

    render json: Oj.dump({
      links: paging[:links],
      meta: paging[:meta],
      data: result_data
    }, mode: oj_mode)
  end

  def show
    begin
      page = Page.find(params[:id])
    rescue ActiveRecord::RecordNotFound
      merge = MergedPage.find(params[:id])
      redirect_to(
        api_v0_page_url(merge.target_uuid),
        status: :permanent_redirect
      ) and return
    end

    data = page.as_json(include: [:maintainers, :tags])
    if should_allow_versions
      data['versions'] = page.versions.as_json
    end
    render json: { data: }
  end

  protected

  def paging_path_for_page(*)
    api_v0_pages_url(*)
  end

  # NOTE: This check can be removed once this issue is resolved.
  # https://github.com/edgi-govdata-archiving/web-monitoring-db/issues/274
  def should_allow_versions
    ActiveModel::Type::Boolean.new.cast(ENV.fetch('ALLOW_VERSIONS_IN_PAGE_RESPONSES', nil))
  end

  def should_include_versions
    boolean_param :include_versions
  end

  def should_include_latest
    if should_allow_versions
      !should_include_versions && boolean_param(:include_latest)
    else
      boolean_param(:include_latest)
    end
  end

  def should_include_earliest
    if should_allow_versions
      !should_include_versions && boolean_param(:include_earliest)
    else
      boolean_param(:include_earliest)
    end
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

    collection = Page.where(params.permit(:title))

    if params.key?(:capture_time)
      collection = where_in_range_param(
        collection.where(versions: { different: true }),
        :capture_time,
        'versions.capture_time'
      ) { |date_string| parse_date!(date_string) }
    end

    collection = where_in_interval_param(collection, :status)

    version_params = params.permit(:hash, :source_type)
    if version_params.present?
      collection = collection.joins(:versions).where(versions: {
        body_hash: params[:hash],
        source_type: params[:source_type]
      }.compact)
    end

    if params[:url]
      query = params[:url]
      collection = collection.joins(:urls)
      if query.include? '*'
        query = query.gsub('%', '\%').gsub('_', '\_').tr('*', '%')
        collection = collection.where('page_urls.url LIKE ?', query)
      else
        collection = collection.where('page_urls.url = ?', query)
      end
    end

    active_test = nullable_boolean_param(:active)
    collection = collection.where(active: active_test) unless active_test.nil?

    # If any queries create implicit joins, ensure we get a list of unique pages
    collection = collection.distinct.order(updated_at: :desc)

    sort_using_params(collection)
  end

  # This is separate from the page_collection method because we want to make
  # sure this filtering is only used to select which *pages* are in the result;
  # we want actual output to include *all* the maintainers/tags on the pages
  # that were matched, not just the ones asked for.
  def filter_maintainers_and_tags(collection)
    if params[:maintainers].is_a?(Array)
      collection = collection
        .left_outer_joins(maintainerships: [:maintainer])
        .where(maintainers: { name: params[:maintainers] })
    end

    if params[:tags].is_a?(Array)
      collection = collection
        .left_outer_joins(taggings: [:tag])
        .where(tags: { name: params[:tags] })
    end

    collection
  end
end
