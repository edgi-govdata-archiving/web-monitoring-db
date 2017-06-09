# Seed the DB with an admin user and a few version records
admin = User.find_or_create_by(admin: true) do |user|
  password = 'PASSWORD'
  user.email = 'seed-admin@example.com'
  user.password = password
  user.confirmed_at = Time.now

  edit_path = Rails.application.routes.url_helpers.edit_user_registration_path
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
