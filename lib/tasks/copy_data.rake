desc 'Copy pages from another web-monitoring-db instance.'
task :copy_page, [:url, :username, :password, :page_uuid] => [:environment] do |_t, args|
  verbose = ENV['VERBOSE']

  page_count = 0
  version_count = 0
  skipped_version_count = 0

  data = api_request("/api/v0/pages/#{args[:page_uuid]}", args)['data']
  page_data = data.clone

  page = Page.find_by(uuid: data['uuid'])
  unless page
    # Pull out relationships to handle separately
    maintainers = page_data.delete('maintainers') || []
    tags = page_data.delete('tags') || []

    page = Page.create!(page_data)
    maintainers.each {|maintainer| page.add_maintainer(maintainer['name'])}
    tags.each {|tag| page.add_tag(tag['name'])}

    page_count += 1
    puts "Copied page #{page.uuid}" if verbose
  end

  version_errors = []
  api_paginated_request("/api/v0/pages/#{args[:page_uuid]}/versions?chunk_size=1000", args) do |version_data|
    if Version.find_by(uuid: version_data['uuid'])
      skipped_version_count += 1
      next
    end

    version = page.versions.create(version_data)
    if version.valid?
      version_count += 1
      puts "  Copied version #{version_data['uuid']}" if verbose
    else
      version_errors << version.uuid
      puts "  Failed to copy version #{version_data['uuid']}:"
      version.errors.full_messages.each { |error| puts "    #{error}" }
    end
  end

  puts "Copied #{page_count} pages and #{version_count} versions from #{args[:url]}"
  puts "Skipped #{skipped_version_count} pre-existing versions" unless skipped_version_count.zero?
  unless version_errors.empty?
    puts "Failed on #{version_errors.length} versions:"
    version_errors.each { |uuid| puts "  #{uuid}" }
  end
end

def api_request(path, options)
  complete_url = /^https?:\/\//.match?(path) ? path : "#{options[:url]}#{path}"
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

def api_paginated_request(path, options, &block)
  next_url = path
  while next_url.present?
    chunk = api_request(next_url, options)
    chunk['data'].each { |item| block.call(item) }
    next_url = chunk['links']['next']
  end
end
