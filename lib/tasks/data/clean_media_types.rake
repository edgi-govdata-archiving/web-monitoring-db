namespace :data do
  desc 'Clean up the media_type field on Versions, remap non-canonical to canonical types.'
  task :clean_media_types, [] => [:environment] do
    ActiveRecord::Migration.say_with_time('Cleaning up media_type on versions...') do
      DataHelpers.with_activerecord_log_level(:error) do
        total = 0

        Version::MEDIA_TYPE_SYNONYMS.each do |bad_type, canonical_type|
          fixed = Version.where(media_type: bad_type).update_all(media_type: canonical_type)
          puts "   #{fixed} versions changed media_type '#{bad_type}' to '#{canonical_type}'"
          total += fixed
        end

        total
      end
    end
  end
end
