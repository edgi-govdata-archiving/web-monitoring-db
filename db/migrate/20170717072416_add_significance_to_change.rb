class AddSignificanceToChange < ActiveRecord::Migration[5.1]
  def change
    add_column(:changes, :significance, :float, null: true, default: nil)
  end
end
