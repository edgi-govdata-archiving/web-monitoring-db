class AddLogFileToImports < ActiveRecord::Migration[5.2]
  def change
    add_column :imports, :log_file, :string
  end
end
