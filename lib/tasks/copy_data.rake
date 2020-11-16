desc 'Copy pages from another web-monitoring-db instance.'
task :copy_page, [:page_uuid, :include_changes, :url, :username, :password] => [:environment] do |_t, args|
  verbose = ENV['VERBOSE']
  begin
    options = {
      url: args[:url] || ENV.fetch('WEB_MONITORING_DB_URL'),
      username: args[:username] || ENV.fetch('WEB_MONITORING_DB_EMAIL'),
      password: args[:password] || ENV.fetch('WEB_MONITORING_DB_PASSWORD')
    }
  rescue KeyError
    instructions = <<~MESSAGE
      You must provide a remote API URL and credentials to copy from, either
      as environment variables:
        WEB_MONITORING_DB_URL='{URL of remote API}'
        WEB_MONITORING_DB_EMAIL='{account e-mail to log in with}'
        WEB_MONITORING_DB_PASSWORD='{account password}'

      Or as command-line arguments:
        rake copy_page['{page ID}','{URL of remote API}','{e-mail}','{password}']
    MESSAGE
    abort(instructions)
  end

  page_count = 0
  version_count = 0
  skipped_version_count = 0
  include_changes = !['', 'f', 'false', '0'].include?((args[:include_changes] || '').strip.downcase)
  change_count = 0
  skipped_change_count = 0

  data = api_request("/api/v0/pages/#{args[:page_uuid]}", options)['data']
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
  api_paginated_request("/api/v0/pages/#{args[:page_uuid]}/versions?chunk_size=1000", options) do |version_data|
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

  annotation_user = User.all.first
  change_errors = []
  if include_changes
    api_paginated_request("/api/v0/pages/#{args[:page_uuid]}/changes?chunk_size=1000", options) do |change_data|
      change = Change.between(from: change_data['uuid_from'], to: change_data['uuid_to'])
      if change.persisted?
        skipped_change_count += 1
        next
      end

      begin
        change.annotate(change_data['current_annotation'], annotation_user)
        change_count += 1
        puts "  Copied change #{change.api_id}" if verbose
      rescue
        change_errors << change.api_id
        puts "  Failed to copy change #{change.api_id}:"
        change.errors.full_messages.each { |error| puts "    #{error}" }
      end
    end
  end

  puts "Copied #{page_count} pages, #{version_count} versions, #{change_count} changes from #{args[:url]}"
  puts "Skipped #{skipped_version_count} pre-existing versions" unless skipped_version_count.zero?
  puts "Skipped #{skipped_change_count} pre-existing changes" unless skipped_change_count.zero?
  unless version_errors.empty?
    puts "Failed on #{version_errors.length} versions:"
    version_errors.each { |uuid| puts "  #{uuid}" }
  end
  unless change_errors.empty?
    puts "Failed on #{change_errors.length} changes:"
    change_errors.each { |uuid| puts "  #{uuid}" }
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
    chunk['data'].each(&block)
    next_url = chunk['links']['next']
  end
end
