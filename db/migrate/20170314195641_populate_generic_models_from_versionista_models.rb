class PopulateGenericModelsFromVersionistaModels < ActiveRecord::Migration[5.0]
  def do_sql(*args)
    expression = ActiveRecord::Base.send :sanitize_sql, args
    ActiveRecord::Base.connection.exec_query(expression)
  end

  def up
    # Add temporary columns to old tables so we can keep track of when copying
    add_column :versionista_pages, :uuid, :string

    # Move data from old tables into new structure (yikes)
    say_with_time 'Copy data to new tables' do
      do_sql('select * from versionista_pages;').each do |old_page|
        page = Page.create!(
          url: old_page['url'],
          title: old_page['title'],
          agency: old_page['agency'],
          site: old_page['site']
        )
        do_sql('UPDATE versionista_pages SET uuid = ? WHERE id = ?', page.uuid, old_page['id'])
      end

      do_sql('select versionista_versions.*, versionista_pages.versionista_url, versionista_pages.versionista_account, versionista_pages.uuid AS page_uuid from versionista_versions LEFT OUTER JOIN versionista_pages ON versionista_versions.page_id = versionista_pages.id ORDER BY versionista_versions.created_at;').each do |old_version|
        versionista_url_parts = old_version['versionista_url'].match(/versionista\.com\/([^\/]+)\/([^\/]+)/)
        page_uuid = old_version['page_uuid']
        version = Version.create!(
          page_uuid: page_uuid,
          capture_time: old_version['created_at'],
          source_type: 'versionista',
          source_metadata: {
            account: old_version['versionista_account'],
            site_id: versionista_url_parts[1],
            page_id: versionista_url_parts[2],
            version_id: old_version['versionista_version_id'],
            page_url: old_version['versionista_url'],
            diff_with_previous_url: old_version['diff_with_previous_url'],
            diff_with_first_url: old_version['diff_with_first_url'],
            diff_length: old_version['diff_length'],
            diff_hash: old_version['diff_hash']
          }
        )

        if old_version['annotations'].present?
          if version.previous.nil?
            raise "TRYING TO ANNOTATE A VERSION WITHOUT A PREVIOUS VERSION:\n#{old_version.as_json}"
          end

          change = Change.create!(
            uuid_from: version.previous.uuid,
            uuid_to: version.uuid
          )

          JSON.parse(old_version['annotations']).each do |old_annotation|
            author = User.find_by_email(old_annotation['author'])
            change.annotate(old_annotation['annotation'], author)
          end
        end
      end
    end
  end

  def down
    raise ActiveRecord::IrreversibleMigration, 'This migration populated new, generic models based on our old Versionista Models. To reverse, restore from a database backup.'
  end
end
