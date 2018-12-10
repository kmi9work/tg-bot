class CreateArticles < ActiveRecord::Migration[5.1]
  def change
    create_table :articles do |t|
      t.text :message
      t.string :type
      t.integer :chat_id
      t.timestamps
    end
  end
end
