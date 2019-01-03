class CreateJoinTableUsersDuties < ActiveRecord::Migration[5.1]
  def change
    create_join_table :users, :duties do |t|
      # t.index [:user_id, :duty_id]
      # t.index [:duty_id, :user_id]
    end
  end
end
