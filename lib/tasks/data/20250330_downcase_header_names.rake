namespace :data do
  desc 'Ensure the names of headers in Version records are downcased.'
  task :'20250330_downcase_header_names', [] => [:environment] do
    ActiveRecord::Migration.say_with_time('Downcasing header names...') do
      DataHelpers.with_activerecord_log_level(:error) do
        progress = DataHelpers::ProgressLogger.new(Version, interval: 10.seconds)
        changed = 0

        Version.in_batches(of: 200, cursor: [:created_at, :uuid]) do |batch|
          changed += DataHelpers.bulk_update(batch, [:headers]) do |version|
            progress.increment

            unless version.headers.blank?
              normalized = Version.normalize_value_for(:headers, version.headers)
              [normalized] if normalized != version.headers
            end
          end
        end

        progress.complete
        changed
      end
    end
  end
end
