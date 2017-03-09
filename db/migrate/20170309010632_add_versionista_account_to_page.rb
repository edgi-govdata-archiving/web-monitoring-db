class AddVersionistaAccountToPage < ActiveRecord::Migration[5.0]
  def change
    change_table :versionista_pages do |t|
      t.string :versionista_account
    end

    # We know all our existing records came from this account, but we don't
    # want this to become the default. Just fill it in for existing records.
    VersionistaPage.update_all(versionista_account: 'andmbergman@gmail.com')
  end
end
