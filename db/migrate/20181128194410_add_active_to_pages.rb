class AddActiveToPages < ActiveRecord::Migration[5.2]
  def change
    add_column :pages, :active, :boolean, default: true
  end
end
