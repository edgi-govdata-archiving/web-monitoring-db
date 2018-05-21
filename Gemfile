source 'https://rubygems.org'

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?("/")
  "https://github.com/#{repo_name}.git"
end

ruby '2.4.1'

gem 'aws-sdk-s3', '~> 1.12'
gem 'devise'
gem 'httparty'
gem 'jwt', '~> 2.1'
gem 'rails', '~> 5.1.6'
gem 'pg', '~> 0.18'
gem 'puma', '~> 3.11'
gem 'rack-cors', :require => 'rack/cors'
gem 'resque'
gem 'sass-rails', '~> 5.0'
gem 'uglifier', '>= 1.3.0'
gem 'oj', '~> 3.6'
gem 'sentry-raven'
gem 'readthis'
gem 'hiredis'
gem 'google-api-client'
gem 'addressable', '~> 2.5'

# See https://github.com/rails/execjs#readme for more supported runtimes
# gem 'therubyracer', platforms: :ruby
# Build JSON APIs with ease. Read more: https://github.com/rails/jbuilder
# gem 'jbuilder', '~> 2.6'
# Use Redis adapter to run Action Cable in production
# gem 'redis', '~> 3.0'
# Use ActiveModel has_secure_password
# gem 'bcrypt', '~> 3.1.7'

# Use Capistrano for deployment
# gem 'capistrano-rails', group: :development

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug', platform: :mri
  gem 'rubocop', '~> 0.56.0', require: false
  gem 'dotenv-rails'
end

group :development do
  gem 'listen', '~> 3.1'
  gem 'pry-rails'
  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring'
  gem 'spring-watcher-listen', '~> 2.0'
  # Access an IRB console on exception pages or by using <%= console %> anywhere in the code.
  gem 'web-console', '>= 3.3.0'
end

group :test do
  gem 'webmock', '~> 3.4'
end

group :production do
  gem 'newrelic_rpm'

  # Send transactional e-mail with Postmark
  gem 'postmark-rails', group: :postmark
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw, :jruby]
