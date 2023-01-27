class Api::V0::UrlsController < Api::V0::ApiController
  before_action(except: [:index, :show]) { authorize(:api, :import?) }

  def index
    urls = page.urls.order('page_urls.to_time DESC')

    render json: {
      links: { page: api_v0_page_url(page) },
      data: urls
    }
  end

  def show
    @page_url ||= page.urls.find(params[:id])
    render json: {
      links: {
        page: api_v0_page_url(page),
        page_urls: api_v0_page_urls_url(page)
      },
      data: @page_url
    }
  end

  def create
    @page_url = page.urls.create!(url_params)
    show
  rescue ActiveRecord::RecordNotUnique
    raise Api::ResourceExistsError, 'This page already has the given URL and timeframe'
  end

  def update
    updates = url_params
    if updates.key?(:url)
      raise Api::UnprocessableError, 'You cannot change a URL\'s `url`'
    end

    @page_url ||= page.urls.find(params[:id])
    @page_url.update(url_params)
    show
  end

  def destroy
    @page_url ||= page.urls.find(params[:id])
    # You cannot delete the canonical URL.
    if @page_url.url == page.url
      raise Api::UnprocessableError, 'You cannot remove the page\'s canonical URL'
    else
      @page_url.destroy
      redirect_to(api_v0_page_urls_url(page))
    end
  end

  protected

  def page
    @page ||= Page.find(params[:page_id])
  end

  def url_params
    result = params
      .require(:page_url)
      .permit(:url, :from_time, :to_time, :notes)

    result.slice('from_time', 'to_time').each do |key, value|
      result[key] = parse_time(key, value)
    end

    result
  end

  def parse_time(field, time_input)
    return if time_input.nil?

    Time.parse(time_input)
  rescue ArgumentError
    raise Api::UnprocessableError, "`#{field}` was not a valid time or `null`"
  end
end
