# Seed the DB with an admin user and a few version records
if Archiver.allowed_hosts.empty?
  puts <<~WARN
    No Archiver allowed hosts configured. This will result in a large download.
    You may set this with the ALLOWED_ARCHIVE_HOSTS environment variable (See .env.example).

    Do you want to continue? [Y]/n
  WARN
  response = STDIN.gets.strip.downcase
  response = response.empty? ? 'y' : response
  if response == 'y'
    puts 'Proceeding'
  else
    abort('Aborting database seeding')
  end
end

admin = User.find_or_create_by(admin: true) do |user|
  password = 'PASSWORD'
  user.email = 'seed-admin@example.com'
  user.password = password
  user.confirmed_at = Time.now

  puts "\n\n------------------------------------------------------------"
  puts "Admin user created with e-mail: #{user.email} and password: #{password}"
  puts "------------------------------------------------------------\n\n"
end

import = Import.create(
  user: admin,
  file: 'seed_import.json'
)

fs_default = FileStorage.default
FileStorage.default = FileStorage::LocalFile.new(path: Rails.root.join('db'))
ImportVersionsJob.perform_now(import)
FileStorage.default = fs_default
