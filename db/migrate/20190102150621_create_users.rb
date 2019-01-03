# frozen_string_literal: true

class CreateUsers < ActiveRecord::Migration[5.1]
  def change
    create_table :users do |t|
      t.boolean :authorized
      t.string :username
      t.string :city
      t.string :cell
      t.string :number
      t.text :jobs
      t.integer :team
      t.integer :timezone
      t.timestamps
    end
  end
end
