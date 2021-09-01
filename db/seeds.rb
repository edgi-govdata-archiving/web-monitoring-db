# Seed the DB with an admin user and a few version records
if Archiver.allowed_hosts.empty?
  puts <<~WARN
    No Archiver allowed hosts configured. This will result in a large download.
    You may set this with the ALLOWED_ARCHIVE_HOSTS environment variable (See .env.example).

    Do you want to continue? [Y]/n
  WARN
  response = $stdin.gets.strip.downcase
  response = 'y' if response.empty?
  if response == 'y'
    puts 'Proceeding'
  else
    abort('Aborting database seeding')
  end
end



admin = User.where('permissions @> ?', '{manage_users}').first
unless admin
  admin = User.new
  password = 'PASSWORD'
  admin.email = 'seed-admin@example.com'
  admin.password = password
  admin.confirmed_at = Time.now
  admin.permissions << 'manage_users'
  admin.save

  puts "\n\n------------------------------------------------------------"
  puts "Admin user created with e-mail: #{admin.email} and password: #{password}"
  puts "------------------------------------------------------------\n\n"
end

import = Import.create(
  user: admin,
  file: 'seed_import.json'
)

fs_default = FileStorage.default
FileStorage.default = FileStorage::LocalFile.new(path: Rails.root.join('db'))

logger = Logger.new($stdout)
logger.level = Logger::INFO
logger.formatter = ->(_severity, _time, _progname, msg) { "--- #{msg}\n" }
Rails.logger.extend(ActiveSupport::Logger.broadcast(logger))

Rails.logger.info 'Importing seeds from db/seed_import.json...'
ImportVersionsJob.perform_now(import)

FileStorage.default = fs_default
