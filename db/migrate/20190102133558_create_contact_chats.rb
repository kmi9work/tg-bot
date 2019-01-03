class CreateContactChats < ActiveRecord::Migration[5.1]
  def change
    create_table :contact_chats do |t|
      t.string :state
      t.integer :chat_id
      t.string :chat_type
      t.belongs_to :user
      t.timestamps
    end
  end
end
