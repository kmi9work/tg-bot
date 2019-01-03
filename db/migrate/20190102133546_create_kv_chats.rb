class CreateKvChats < ActiveRecord::Migration[5.1]
  def change
    create_table :kv_chats do |t|

      t.timestamps
    end
  end
end
