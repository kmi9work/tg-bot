class CreateChats < ActiveRecord::Migration[5.1]
  def change
    create_table :chats do |t|
      t.integer :chat_id
      t.string :chat_type
      t.timestamps
    end
  end
end
