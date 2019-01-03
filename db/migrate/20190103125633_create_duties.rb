class CreateDuties < ActiveRecord::Migration[5.1]
  def change
    create_table :duties do |t|
      t.integer :team
      t.string :number
      t.string :leader
      t.date :day
      t.integer :start_hour
      t.timestamps
    end
  end
end
