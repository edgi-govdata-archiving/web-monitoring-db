desc 'Copy pages from another web-monitoring-db instance.'
task :copy_page, [:page_uuid, :include_changes, :url, :username, :password] => [:environment] do |_t, args|
  verbose = ENV.fetch('VERBOSE', nil)
  include_changes = args[:include_changes].present?

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

  page, page_count = copy_page_data(args[:page_uuid], options, verbose)
  versions = copy_page_versions(page, options, verbose)

  changes = if include_changes
              copy_page_changes(page, options, verbose)
            else
              { count: 0, skipped: 0, errors: [] }
            end

  puts "Copied #{page_count} pages, #{versions[:count]} versions, #{changes[:count]} changes from #{args[:url]}"
  puts "Skipped #{versions[:skipped]} pre-existing versions" unless versions[:skipped].zero?
  puts "Skipped #{changes[:skipped]} pre-existing changes" unless changes[:skipped].zero?
  unless versions[:errors].empty?
    puts "Failed on #{versions[:errors].length} versions:"
    versions[:errors].each { |uuid| puts "  #{uuid}" }
  end
  unless changes[:errors].empty?
    puts "Failed on #{changes[:errors].length} changes:"
    changes[:errors].each { |uuid| puts "  #{uuid}" }
  end
end

def copy_page_data(page_uuid, api_options, verbose)
  page_count = 0
  data = api_request("/api/v0/pages/#{page_uuid}", api_options)['data']
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

  [page, page_count]
end

def copy_page_versions(page, api_options, verbose)
  summary = { count: 0, skipped: 0, errors: [] }

  versions_path = "/api/v0/pages/#{page.uuid}/versions?chunk_size=1000&sort=capture_time:asc"
  api_paginated_request(versions_path, api_options) do |version_data|
    version = Version.find_by(uuid: version_data['uuid'])
    if version
      if version.page_uuid.nil?
        version.update(page_uuid: page.uuid)
        summary[:count] += 1
        puts "  Updated version #{version_data['uuid']}" if verbose
      else
        summary[:skipped] += 1
      end
      next
    end

    version = page.versions.create(version_data)
    if version.valid?
      summary[:count] += 1
      puts "  Copied version #{version_data['uuid']}" if verbose
    else
      summary[:errors] << version.uuid
      puts "  Failed to copy version #{version_data['uuid']}:"
      version.errors.full_messages.each { |error| puts "    #{error}" }
    end
  end

  summary
end

def copy_page_changes(page, api_options, verbose)
  annotation_user = User.all.first
  summary = { count: 0, skipped: 0, errors: [] }

  changes_path = "/api/v0/pages/#{page.uuid}/changes?chunk_size=1000&sort=created_at:asc"
  api_paginated_request(changes_path, api_options) do |change_data|
    change = Change.between(from: change_data['uuid_from'], to: change_data['uuid_to'])
    if change.persisted?
      summary[:skipped] += 1
      next
    end

    begin
      change.annotate(change_data['current_annotation'], annotation_user)
      summary[:count] += 1
      puts "  Copied change #{change.api_id}" if verbose
    rescue StandardError
      summary[:errors] << change.api_id
      puts "  Failed to copy change #{change.api_id}:"
      change.errors.full_messages.each { |error| puts "    #{error}" }
    end
  end

  summary
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

def api_paginated_request(path, options, &)
  next_url = path
  while next_url.present?
    chunk = api_request(next_url, options)
    chunk['data'].each(&)
    next_url = chunk['links']['next']
  end
end
