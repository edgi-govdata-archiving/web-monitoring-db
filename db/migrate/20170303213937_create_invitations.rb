# frozen_string_literal: true

class CreateInvitations < ActiveRecord::Migration[5.0]
  def change
    create_table :invitations do |t|
      t.belongs_to :issuer, foreign_key: { to_table: :users }
      t.belongs_to :redeemer, foreign_key: { to_table: :users }
      t.string :code
      t.string :email
      t.datetime :expires_on
      t.timestamps

      t.index :code
    end
  end
end
