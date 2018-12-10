class CreateArticles < ActiveRecord::Migration[5.1]
  def change
    create_table :articles do |t|
      t.text :message
      t.string :article_type
      t.integer :chat_id
      t.integer :message_id
      t.timestamps
    end
  end
end
