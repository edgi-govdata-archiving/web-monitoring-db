source 'https://rubygems.org'

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?("/")
  "https://github.com/#{repo_name}.git"
end

ruby file: ".ruby-version"

gem 'aws-sdk-s3', '~> 1.198'
gem 'concurrent-ruby', '~> 1.3'
gem 'devise'
gem 'httparty'
gem 'jwt', '~> 3.1'
gem 'rails', '~> 8.0.2'
gem 'pg', '~> 1.6'
gem 'puma', '~> 6.6'
gem 'rack-cors', '~> 3.0', :require => 'rack/cors'
gem 'rack-brotli'
gem 'sassc-rails', '~> 2.1.2'
gem 'uglifier', '>= 1.3.0'
gem 'oj', '~> 3.16'
gem 'pundit', '~> 2.5.0'
gem 'google-apis-sheets_v4'
gem 'addressable', '~> 2.8'

# Workers/Queuing
gem "good_job", "~> 4.11"

# Caching
gem 'redis', '~> 5.4'
gem 'hiredis'

# Monitoring & Telemetry
gem 'sentry-ruby', '~> 5.26.0'
gem 'sentry-rails', '~> 5.26.0'

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

# Reduces boot times through caching; required in config/boot.rb
gem 'bootsnap', '>= 1.4.5', require: false

group :development, :test do
  # Call 'byebug' anywhere in the code to stop execution and get a debugger console
  gem 'byebug', platform: :mri
  gem 'rubocop', '~> 1.81.1', require: false
  gem 'rubocop-performance', '~> 1.25.0'
  gem 'rubocop-rails', '~> 2.33.3'
  gem 'dotenv'
end

group :development do
  gem 'listen', '~> 3.9'
  gem 'pry-rails'
  # Access an IRB console on exception pages or by using <%= console %> anywhere in the code.
  gem 'web-console', '>= 4.0.2'
end

group :test do
  gem 'capybara'
  gem 'capybara-email'
  gem 'webmock', '~> 3.25'
  # NOTE: Rails requires Selenium Webdriver to be present in order to run system tests, regardless of what driver
  # you're actually using. See also https://github.com/rails/rails/issues/37410
  gem 'selenium-webdriver'
end

group :production do
  # Send transactional e-mail with Postmark
  gem 'postmark-rails', group: :postmark
end

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem 'tzinfo-data', platforms: [:mingw, :mswin, :x64_mingw, :jruby]
