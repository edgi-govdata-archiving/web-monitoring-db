# From https://github.com/edgi-govdata-archiving/versionista-outputter

require 'date'
require 'chronic'
require 'securerandom'
require_relative 'browser.rb'
require_relative 'page_diff.rb'

module VersionistaService
  RETRY_WAIT_TIME = 30
  
  class Scraper
    attr_reader :session, :cutoff_time, :until_time, :should_get_all_versions, :chill_between_sites, :chill_between_pages
    
    def self.from_hours(cutoff_hours, until_hours = 0, chill_between_sites = 5, chill_between_pages = 5)
      self.new(
        DateTime.now - (cutoff_hours.to_i / 24.0),
        DateTime.now - (until_hours.to_i / 24.0),
        chill_seconds)
    end

    def initialize(cutoff_time, until_time = nil, get_all_versions = true, chill_between_sites = 5, chill_between_pages = 5)
      @session = Browser.new_session
      @cutoff_time = cutoff_time
      @until_time = until_time || DateTime.now
      @should_get_all_versions = get_all_versions
      @chill_between_sites = chill_between_sites
      @chill_between_pages = chill_between_pages
      @retry_count = 0
    end
    
    def navigate_to!(url)
      begin
        session.visit(url)
      rescue Capybara::Poltergeist::StatusFailError => error
        if @retry_count < 3
          wait_multiplier = 2 ** @retry_count
          sleep(RETRY_WAIT_TIME * wait_multiplier)
          @retry_count += 1
          navigate_to!(url)
        else
          raise error
        end
      ensure
        @retry_count = 0
      end
    end
    
    def navigate_to(url)
      begin
        navigate_to! url
        true
      rescue Capybara::Poltergeist::StatusFailError => error
        false
      end
    end

    def log_in(email:, password:)
      puts "Logging in..."

      navigate_to!(log_in_url)
      session.fill_in("E-mail", with: email)
      session.fill_in("Password", with: password)
      session.click_button("Log in")
      
      if session.has_xpath?("//a[contains(text(), 'Log out')]")
        puts "-- Logging in complete!"
        true
      else
        puts "-- Logging in failed!"
        false
      end
    end

    def scrape_each_page_version
      website_rows = scrape_website_hrefs

      first_site = true
      website_rows.map do |name, href, change_time|
        next if change_time < cutoff_time
        
        unless first_site || chill_between_sites == 0
          sleep(chill_between_sites)
        end
        first_site = false
        
        [name, scrape_archived_page_data(href)]
      end.compact
    end

    def headers
      [
        'Index',
        "UUID",
        "Output Date/Time",
        'Agency',
        "Site Name",
        'Page name',
        'URL',
        'Page View URL',
        "Last Two - Side by Side",
        "Latest to Base - Side by Side",
        "Date Found - Latest",
        "Date Found - Base",
        "Diff Length",
        "Diff Hash",
      ]
    end

    private

    def log_in_url
      "https://versionista.com/login"
    end

    def scrape_website_hrefs
      navigate_to!("https://versionista.com/home")
      session.find(:xpath, "//a[contains(text(), 'Show all')]").click
      site_rows = session.all(:xpath, "//th[contains(text(), 'Sites')]/../../following-sibling::tbody/tr")

      site_rows.map do |row|
        link = row.find(:xpath, "./td[a]/a")
        change_time = parsed_website_change_time(row.find(:xpath, "./td[5]").text)

        [link.text, link[:href], change_time]
      end
    end

    def parsed_website_change_time(time_ago)
      DateTime.parse(Chronic.parse("#{time_ago} ago").to_s)
    end

    def recent_page_hrefs
      all_page_rows = session.all(:xpath, "//div[contains(text(), 'URL')]/../../../following-sibling::tbody/tr")
      recent_page_rows = all_page_rows.select { |row| happened_in_last_n_hours?(row) }
      recent_page_rows.map { |row| row.find(:xpath, "./td[a][2]/a")[:href] }
    end

    def happened_in_last_n_hours?(row)
      last_new_time_cell = row.all(:xpath, "./td[9]").first

      if last_new_time_cell.nil?
        false
      else
        # Need to better determine when to add the TZ adjustment here
        est_adjustment = 0 #(5.0/24)
        begin
          version_time = DateTime.strptime(last_new_time_cell.text, "%b %d %Y %I:%M %p") + est_adjustment
          version_time >= cutoff_time
        rescue ArgumentError #invalid date
          false
        end
      end
    end

    def scrape_archived_page_data(href)
      puts "Visiting #{href}"
      unless navigate_to(href)
        puts "-- FAILED VISIT"
        return []
      end
      puts "-- Successful visit!"

      site_name = session.all(:xpath, "//i[contains(text(), 'Custom:')]").first.text.sub("Custom: ", "")

      page_hrefs = []
      page_hrefs.concat(recent_page_hrefs)

      i = 2
      while((next_link = session.all(:xpath, "//li[not(@class='disabled')]/a[contains(text(), 'Next')]").first) && i <= 20)
        puts "Clicking Next to visit page #{i} of list of archived pages..."
        next_link.click
        i += 1
        puts "-- Successful visit!"

        page_hrefs.concat(recent_page_hrefs)
      end

      first_page = true
      page_hrefs.flat_map do |href|
        unless first_page || chill_between_pages == 0
          sleep(chill_between_pages)
        end
        first_page = false
        
        puts "Visiting #{href}"
        unless navigate_to(href)
          puts "-- FAILED VISIT"
          return []
        end
        puts "-- Successful visit!"

        page_name = session.all(:xpath, "//div[@class='panel-heading']//h3").first.text
        page_url = session.all(:xpath, "//div[@class='panel-heading']//h3/following-sibling::a[1]").first.text
        comparison_links = session.all(:xpath, "//*[@id='pageTableBody']/tr/td[1]/a")
        
        versions_data = if should_get_all_versions
          parse_all_comparison_data(comparison_links)
        else
          parse_comparison_data(comparison_links)
        end
        
        versions_data.map do |version_data|
          # The original version will not have a total_comparison_url
          # (why yes, this a crappy hack on top of something not designed for this)
          latest_diff = if version_data[:total_comparison_url]
            comparison_diff(version_data[:latest_comparison_url])
          else
            PageDiff.new
          end
          
          [
            href,
            data_row(
              page_view_url: href,
              site_name: site_name,
              page_name: page_name,
              page_url: page_url,
              latest_comparison_date: version_data[:latest_comparison_date],
              oldest_comparison_date: version_data[:oldest_comparison_date],
              latest_comparison_url: version_data[:latest_comparison_url],
              total_comparison_url: version_data[:total_comparison_url],
              latest_diff: latest_diff,
            )
          ]
        end
      end
    end

    def parse_comparison_data(comparison_links)
      latest_link = comparison_links.first
      oldest_link = comparison_links.last
      return [] if latest_link.nil? || oldest_link.nil?

      [{
        latest_comparison_date: latest_link.text,
        oldest_comparison_date: oldest_link.text,
        latest_comparison_url: generated_latest_comparison_url(latest_link),
        total_comparison_url: generated_total_comparison_url(latest_link, oldest_link),
      }]
    end
    
    def parse_all_comparison_data(comparison_links)
      versions = []
      oldest_link = comparison_links.last
      
      if !oldest_link.nil?
        comparison_links.reverse_each do |link|
          latest_comparison_url = link[:href]
          total_comparison_url = nil
          
          version_date = DateTime.parse(Chronic.parse(link.text).to_s)
          next if version_date < cutoff_time || version_date > until_time
          
          if link != oldest_link
            latest_comparison_url = generated_latest_comparison_url(link)
            total_comparison_url = generated_total_comparison_url(link, oldest_link)
          end
          
          versions.push({
            latest_comparison_date: link.text,
            oldest_comparison_date: oldest_link.text,
            latest_comparison_url: latest_comparison_url,
            total_comparison_url: total_comparison_url,
          })
        end
      end
      
      versions
    end

    def generated_latest_comparison_url(latest_link)
      latest_link[:href].sub(/\/?$/, ":0/")
    end

    def generated_total_comparison_url(latest_link, oldest_link)
      oldest_version_id = oldest_link[:href].slice(/\d+\/?$/).sub('/', '')
      latest_link[:href].sub(/\/?$/, ":#{oldest_version_id}/")
    end

    def comparison_diff(url)
      page_diff = PageDiff.new

      begin
        puts "Visiting the comparison url: #{url}"
        navigate_to(url)
        puts "-- Successful visit!"
        page_diff.diff_text = source_changes_only_diff
      rescue Capybara::ExpectationNotMet,
          Capybara::ElementNotFound,
          Capybara::Poltergeist::StatusFailError

        puts "__Error getting diff from: #{url}"
        puts "-" * 80
      end

      page_diff
    end

    def source_changes_only_diff
      session.within_frame(0) do
        unless session.find("#viewer_chooser").value == "only"
          session.select("source: changes only", from: "viewer_chooser")
        end
      end

      session.within_frame(1) do
        session.has_selector?("body s")
        session.find("body")[:innerHTML]
      end
    end

    def data_row(page_view_url:, site_name:, page_name:,
                 page_url:, latest_comparison_url:, total_comparison_url:,
                 latest_comparison_date:, oldest_comparison_date:, latest_diff:)
    
      headers.zip([
        nil,                         #'Index' - to be filled in later
        SecureRandom.uuid,           # UUID
        Time.now.to_s,               #"Output Date/Time"
        tokenized_agency(site_name), #'Agency'
        site_name,                   #"Site Name"
        page_name,                   #'Page name'
        page_url,                    #'URL'
        page_view_url,               #'Page View URL'
        latest_comparison_url,       #"Last Two - Side by Side"
        total_comparison_url,        #"Latest to Base - Side by Side"
        latest_comparison_date,      #"Date Found - Latest"
        oldest_comparison_date,      #"Date Found - Base"
        latest_diff.length,          # Diff length
        latest_diff.hash,            # Diff hash
      ]).to_h
    end

    def tokenized_agency(site_name)
      site_name.split("-").first.strip
    end
  end
end
