require 'date'
require 'json'
require_relative '../versionista_service/scraper.rb'

desc 'Update database entries by scraping Versionista'
task :update_from_versionista, [:from, :to, :email, :password] => [:environment] do |_, args|
  from_date, to_date = get_timeframe(args)
  email, password = get_credentials(args)

  websites_data = scrape_versionista(email, password, from_date, to_date)
  update_db_from_data(websites_data)
end


desc 'Scraping Versionista for new revisions'
task :scrape_from_versionista, [:from, :to, :output_path, :email, :password] => [:environment] do |_, args|
  from_date, to_date = get_timeframe(args)
  email, password = get_credentials(args)

  websites_data = scrape_versionista(email, password, from_date, to_date)
  data_path = args.output_path || "./tmp/scraped_data-#{args.from}-#{args.to}.json"

  File.write(data_path, websites_data.to_json)
end


desc 'Update database entries from pre-scraped Versionista data'
task :update_from_json, [:data_path] => [:environment] do |_, args|
  raw_data = File.read(args.data_path)
  data = JSON.parse(raw_data)
  update_db_from_data(data)
end

desc 'Update database entries from a directory of pre-scraped Versionista data'
task :update_from_json_directory, [:data_path] => [:environment] do |_, args|
  Dir.entries(args.data_path).each do |entry|
    if entry.match?(/^page/)
      data = JSON.parse(File.read(File.join(args.data_path, entry)))
      begin
        update_db_from_data([[entry, data]])
      ensure
        puts data.length
      end
    end
  end
end


# Actual implementations

# Get intended timeframe based on args. Throw if from/to args are not either ISO 8601 dates or floats.
def get_timeframe(args)
  from_date = nil
  to_date = nil
  args.with_defaults(:from => '6', :to => '0')

  begin
    from_date = DateTime.iso8601(args.from)
  rescue
    from_date = DateTime.now - (Float(args.from) / 24.0)
  end

  begin
    to_date = DateTime.iso8601(args.to)
  rescue
    to_date = DateTime.now - (Float(args.to) / 24.0)
  end

  [from_date, to_date]
end

# Get versionista credentials based on args/env
def get_credentials(args)
  email = args.email
  if email.blank?
    email = ENV.fetch('VERSIONISTA_EMAIL', nil)
  end

  password = args.password
  if password.blank?
    password = ENV.fetch('VERSIONISTA_PASSWORD', nil)
  end

  if email.blank? || password.blank?
    raise 'You must provide an e-mail and password for Versionista, either as arguments or as environment variables: VERSIONISTA_EMAIL and VERSIONISTA_PASSWORD'
  end

  [email, password]
end

def scrape_versionista(email, password, from_date, to_date)
  start_time = DateTime.now
  puts "Scraping Versionista data from #{from_date} through #{to_date}"

  scraper = VersionistaService::Scraper.new(from_date, to_date)
  unless scraper.log_in(email: email, password: password)
    raise 'Could not log in; stopping Versionista update.'
  end

  result = scraper.scrape_each_page_version

  duration = ((DateTime.now - start_time) * 24 * 60).to_f.round 3
  puts "Completed scraping in #{duration} minutes"

  result
end

def update_db_from_data(websites_data)
  def parse_date(date)
    begin
      DateTime.parse(Chronic.parse(date).to_s)
    rescue
      nil
    end
  end

  websites_data.each do |_website_name, data|
    # Make dates actual DateTime objects; sort by update date ascending
    sorted = data.map do |item|
      item[1]['Date Found - Base'] = parse_date(item[1]['Date Found - Base'])
      item[1]['Date Found - Latest'] = parse_date(item[1]['Date Found - Latest'])
      item
    end.sort do |version1, version2|
      version1[1]['Date Found - Latest'] <=> version2[1]['Date Found - Latest']
    end

    sorted.each do |versionista_url, diff_data|
      page_url = diff_data['URL']
      # Turns out Versionista is currently scraping the same page under multiple scraping routines, resulting in
      # multiple records for the the same page. Use the Versionista URL to keep them separate for now... >:(
      # https://github.com/edgi-govdata-archiving/web-monitoring-db/pull/24
      # is tracking cleanup for this.

      pre_existing_version = Version.where(
        "source_type = 'versionista' AND source_metadata->>'page_url' = ?",
        versionista_url
      ).first
      page = pre_existing_version.try(:page)
      if page.nil?
        page = Page.create(
          url: page_url,
          title: diff_data['Page name'],
          agency: diff_data['Agency'],
          site: diff_data['Site Name'])
        unless page.valid?
          puts "Error creating new page ('#{page.title}' - '#{page.url}'):"
          puts (page.errors.full_messages.map {|error| "  #{error}"})
          next
        end
        puts "Tracking new page: '#{page.title}' (#{page.url})"
      end

      # Add the actual version if not already present
      diff_with_previous_url = diff_data['Last Two - Side by Side']
      version_id_match = diff_with_previous_url.match(/versionista\.com\/\w+\/\w+\/(\w+)(?:\:(\w+))?/)
      versionista_version_id = version_id_match ? version_id_match[1] : nil

      if versionista_version_id.nil?
        puts "!! Could not find Versionista version ID for #{diff_data}"
      end

      version = Version.where(
        "page_uuid = ? AND source_type = 'versionista' AND source_metadata->>'version_id' = ?",
        page.id,
        versionista_version_id
      ).first

      if version
        puts "- Already have '#{page.url}' - \##{version.source_metadata['version_id']}"
      else
        versionista_url_parts = versionista_url.match(/versionista\.com\/([^\/]+)\/([^\/]+)/)
        version = page.versions.create(
          # NOTE: we do not yet have version content, so not recording `uri`, `version_hash`
          capture_time: diff_data['Date Found - Latest'],
          source_type: 'versionista',
          source_metadata: {
            account: diff_data['versionista_account'],
            site_id: versionista_url_parts[1],
            page_id: versionista_url_parts[2],
            version_id: versionista_version_id,
            page_url: versionista_url,
            diff_with_previous_url: diff_data['Last Two - Side by Side'],
            diff_with_first_url: diff_data['Latest to Base - Side by Side'],
            diff_length: diff_data['Diff Length'],
            diff_hash: diff_data['Diff Hash']
          }
        )
        puts "+ Found new version of '#{page.url}' - \##{version.source_metadata['version_id']}"
      end
    end
  end
end
