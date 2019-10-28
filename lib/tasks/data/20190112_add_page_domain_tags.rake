namespace :data do
  desc 'Set `domain:` and `2l-domain` tags on all pages.'
  task :'20190112_add_page_domain_tags', [] => [:environment] do |_t|
    ActiveRecord::Migration.say_with_time('Updating domain tags on pages...') do
      DataHelpers.with_activerecord_log_level(:error) do
        last_update = Time.now
        completed = 0
        total = Page.all.count

        DataHelpers.iterate_each(Page.all.order(created_at: :asc), batch_size: 500) do |page|
          page.ensure_domain_tags
          completed += 1
          if Time.now - last_update > 2
            DataHelpers.log_progress(completed, total, description: 'pages tagged')
            last_update = Time.now
          end
        end

        DataHelpers.log_progress(completed, total, end_line: true, description: 'pages tagged')
        completed
      end
    end
  end
end
