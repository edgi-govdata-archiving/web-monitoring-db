desc 'Copy pages from another web-monitoring-db instance.'
task :copy_page, [:url, :username, :password, :page_uuid] => [:environment] do |_t, args|
  verbose = ENV['VERBOSE']

  page_url = "#{args[:url]}/api/v0/pages/#{args[:page_uuid]}"
  response = HTTParty.get(page_url, basic_auth: {
    username: args[:username],
    password: args[:password]
  })

  raise "Error getting data: #{response.body}" if response.code != 200

  page_count = 0
  version_count = 0

  data = JSON.parse(response.body)['data']
  page_data = data.clone
  page_data.delete('versions')

  page = Page.find_by(uuid: data['uuid'])
  unless page
    page = Page.create(page_data)
    page_count += 1
    puts "Copied page #{page.uuid}" if verbose
  end

  data['versions'].each do |version_data|
    next if Version.find_by(uuid: version_data['uuid'])

    page.versions.create(version_data)
    version_count += 1
    puts "  Copied version #{version_data['uuid']}" if verbose
  end

  puts "Copied #{page_count} pages and #{version_count} versions from #{args[:url]}"
end
