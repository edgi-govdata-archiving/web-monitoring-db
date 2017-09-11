class AddTitleToVersions < ActiveRecord::Migration[5.1]
  def change
    add_column :versions, :title, :string
    Version.includes(:page).find_each do |v|
      puts "Updated Version record with UUID #{v.uuid} to have title '#{v.title}'" if v.update(title: v.page.title)
    end
  end
end
