namespace :data do
  desc 'Remove bad version titles from Versionista.'
  task :'20230119_remove_bad_versionista_titles', [] => [:environment] do |_t, _args|
    ActiveRecord::Migration.say_with_time('Removing bad titles from Versionista versions...') do
      DataHelpers.with_activerecord_log_level(:error) do
        Version
          .where(source_type: 'versionista')
          .where(title: [
                   # These titles are or appear to have been text strings from the
                   # Versionista UI to represent documents without titles, or where
                   # the title could not be ascertained, rather than the document's
                   # actual title.
                   'None',
                   'No title available',
                   'No title yet',
                   'Your page is missing!'
                 ])
          .update_all(title: '')
      end
    end
  end
end
