# From https://github.com/edgi-govdata-archiving/versionista-outputter

require 'capybara/poltergeist'

module VersionistaService
  class Browser
    def self.new_session
      Capybara.register_driver :poltergeist do |app|
        Capybara::Poltergeist::Driver.new(app, js_errors: false)
      end

      # Configure Capybara to use Poltergeist as the driver
      Capybara.default_driver = :poltergeist

      if ENV['PAGE_WAIT_TIME']
        Capybara.default_max_wait_time = ENV['PAGE_WAIT_TIME'].to_f
      end

      Capybara.current_session
    end
  end
end
