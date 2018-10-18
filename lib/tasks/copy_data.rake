desc 'Copy pages from another web-monitoring-db instance.'
task :copy_page, [:url, :username, :password, :page_uuid] => [:environment] do |_t, args|
  verbose = ENV['VERBOSE']

  page_count = 0
  version_count = 0

  data = api_request("/api/v0/pages/#{args[:page_uuid]}", args)['data']
  page_data = data.clone

  page = Page.find_by(uuid: data['uuid'])
  unless page
    # Pull out relationships to handle separately
    maintainers = page_data.delete('maintainers') || []
    tags = page_data.delete('tags') || []

    page = Page.create(page_data)
    maintainers.each {|maintainer| page.add_maintainer(maintainer['name'])}
    tags.each {|tag| page.add_tag(tag['name'])}

    page_count += 1
    puts "Copied page #{page.uuid}" if verbose
  end

  versions = api_request("/api/v0/pages/#{args[:page_uuid]}/versions", args)['data']
  versions.each do |version_data|
    next if Version.find_by(uuid: version_data['uuid'])

    page.versions.create(version_data)
    version_count += 1
    puts "  Copied version #{version_data['uuid']}" if verbose
  end

  puts "Copied #{page_count} pages and #{version_count} versions from #{args[:url]}"
end

def api_request(path, options)
  complete_url = "#{options[:url]}#{path}"
  response = HTTParty.get(complete_url, basic_auth: {
    username: options[:username],
    password: options[:password]
  })
  begin
    parsed = JSON.parse(response.body)
    raise "Error getting data: #{parsed['error']}" if parsed.key?('error')
    raise "Error getting data: #{parsed['errors']}" if parsed.key?('errors')
    raise "Error getting data: #{response.body}" if response.code != 200

    parsed
  rescue JSON::ParserError
    raise "Error parsing data: #{response.body}"
  end
end
