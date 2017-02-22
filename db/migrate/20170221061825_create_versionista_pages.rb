class CreateVersionistaPages < ActiveRecord::Migration[5.0]
  def change
    create_table :versionista_pages do |t|
      t.string :url
      t.string :title
      t.string :agency
      t.string :site
      t.string :versionista_url

      t.timestamps
      
      t.index :url
    end
  end
end
