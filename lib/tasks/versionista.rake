require 'date'
require 'json'
require_relative '../versionista_service/scraper.rb'

desc 'Update database entries by scraping Versionista'
task :update_from_versionista, [:from, :to, :email, :password] => [:environment] do |t, args|
  args.with_defaults(:from => '6', :to => '0')
  from_date = DateTime.now - (args.from.to_f / 24.0)
  to_date = DateTime.now - (args.to.to_f / 24.0)
  email, password = get_credentials(args)
  
  websites_data = scrape_versionista(email, password, from_date, to_date)
  update_db_from_data(websites_data)
end


desc 'Scraping Versionista for new revisions'
task :scrape_from_versionista, [:from, :to, :output_path, :email, :password] => [:environment] do |t, args|
  args.with_defaults(:from => '6', :to => '0')
  from_date = DateTime.now - (args.from.to_f / 24.0)
  to_date = DateTime.now - (args.to.to_f / 24.0)
  email, password = get_credentials(args)
  
  websites_data = scrape_versionista(email, password, from_date, to_date)
  data_path = args.output_path || "./tmp/scraped_data-#{args.from}-#{args.to}.json"
  
  File.write(data_path, websites_data.to_json)
end


desc 'Update database entries from pre-scraped Versionista data'
task :update_from_json, [:data_path] => [:environment] do |t, args|
  raw_data = File.read(args.data_path)
  data = JSON.parse(raw_data)
  update_db_from_data(data)
end


# Actual implementations

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
    fail "You must provide an e-mail and password for Versionista, either as arguments or as environment variables: VERSIONISTA_EMAIL and VERSIONISTA_PASSWORD"
  end
  
  [email, password]
end

def scrape_versionista(email, password, from_date, to_date)
  start_time = DateTime.now
  puts "Scraping Versionista data from #{from_date} through #{to_date}"
  
  scraper = VersionistaService::Scraper.new(from_date, to_date)
  unless scraper.log_in(email: email, password: password)
    fail 'Could not log in; stopping Versionista update.'
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
  
  websites_data.each do |website_name, data|
    # Make dates actual DateTime objects; sort by update date ascending
    sorted = data.map do |item|
      item[1]['Date Found - Base'] = parse_date(item[1]['Date Found - Base'])
      item[1]['Date Found - Latest'] = parse_date(item[1]['Date Found - Latest'])
      item
    end.sort do |version1, version2|
      version1[1]['Date Found - Latest'] <=> version2[1]['Date Found - Latest']
    end
    
    data.each do |versionista_url, diff_data|
      page_url = diff_data['URL']
      # Turns out Versionista is currently scraping the same page under multiple scraping routines, resulting in
      # multiple records for the the same page. Use the Versionista URL to keep them separate for now... >:(
      # page = VersionistaPage.find_by(url: page_url)
      page = VersionistaPage.find_by(versionista_url: versionista_url)
      if page.nil?
        page = VersionistaPage.new(
          url: page_url,
          title: diff_data['Page name'],
          agency: diff_data['Agency'],
          site: diff_data['Site Name'],
          versionista_url: versionista_url,
          created_at: diff_data['Date Found - Base'])
        puts "Tracking new page: '#{page.title}' (#{page.url})"
      end
      
      updated_at = diff_data['Date Found - Latest']
      if !page.updated_at || (updated_at && page.updated_at < updated_at)
        page.updated_at = updated_at
      end
      
      page.save
      
      diff_with_previous_url = diff_data['Latest to Base - Side by Side']
      version_id_match = diff_with_previous_url.match(/versionista\.com\/\w+\/\w+\/(\w+)(?:\:(\w+))?/)
      versionista_version_id = version_id_match ? version_id_match[1] : nil
      versionista_previous_id = version_id_match ? version_id_match[2] : nil
      
      version = VersionistaVersion.find_by(page_id: page.id, versionista_version_id: versionista_version_id)
      previous = VersionistaVersion.find_by(page_id: page.id, versionista_version_id: versionista_previous_id)
      unless version
        version = VersionistaVersion.create(
          versionista_version_id: versionista_version_id,
          page: page,
          previous: previous,
          diff_with_previous_url: diff_data['Last Two - Side by Side'],
          diff_with_first_url: diff_data['Latest to Base - Side by Side'],
          diff_length: diff_data['Diff Length'],
          diff_hash: diff_data['Diff Hash'],
          created_at: updated_at)
        puts "Found new version of '#{page.url}' - \##{version.versionista_version_id}"
      end
    end
  end
end
