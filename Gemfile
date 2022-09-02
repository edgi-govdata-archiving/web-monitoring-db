source 'https://rubygems.org'

git_source(:github) do |repo_name|
  repo_name = "#{repo_name}/#{repo_name}" unless repo_name.include?("/")
  "https://github.com/#{repo_name}.git"
end

ruby '3.1.2'

# Ruby 3 split out some modules into gems that other packages do not yet
# require. We should watch for when we can remove these as direct dependencies.
# (Probably with an upgrade to Rails 7)
gem 'net-smtp'
gem 'net-pop'

gem 'aws-sdk-s3', '~> 1.114'
gem 'concurrent-ruby', '~> 1.1'
gem 'devise'
gem 'httparty'
gem 'jwt', '~> 2.5'
gem 'rails', '~> 6.1.6.1'
gem 'pg', '~> 1.4'
gem 'puma', '~> 5.6'
gem 'rack-cors', :require => 'rack/cors'
gem 'rack-brotli'
gem 'sassc-rails', '~> 2.1.2'
gem 'uglifier', '>= 1.3.0'
gem 'oj', '~> 3.13'
gem 'pundit', '~> 2.2.0'
gem 'google-apis-sheets_v4'
gem 'addressable', '~> 2.8'

# Workers/Queuing
# Resque 2.3.0 is not compatible with Redis v5; if updated, see about updating
# the redis gem as well. See: https://github.com/resque/resque/pull/1828
gem 'resque', '~> 2.3.0'
# gem 'resque-heroku-signals'
gem 'redis', '~> 4.8'
gem 'hiredis'

# Monitoring & Telemetry
gem 'sentry-ruby', '~> 5.4.2'
gem 'sentry-rails', '~> 5.4.1'

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
  gem 'rubocop', '~> 1.36.0', require: false
  gem 'rubocop-performance', '~> 1.14.3'
  gem 'rubocop-rails', '~> 2.15.2'
  gem 'dotenv-rails'
end

group :development do
  gem 'listen', '~> 3.7'
  gem 'pry-rails'
  # Spring speeds up development by keeping your application running in the background. Read more: https://github.com/rails/spring
  gem 'spring'
  gem 'spring-watcher-listen', '~> 2.0'
  # Access an IRB console on exception pages or by using <%= console %> anywhere in the code.
  gem 'web-console', '>= 4.0.2'
end

group :test do
  gem 'capybara'
  gem 'capybara-email'
  gem 'webmock', '~> 3.18'
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
