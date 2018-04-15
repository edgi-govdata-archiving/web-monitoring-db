class AddProcessingWarningsToImports < ActiveRecord::Migration[5.1]
  def change
    add_column :imports, :processing_warnings, :jsonb
  end
end
