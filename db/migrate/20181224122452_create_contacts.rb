class CreateContacts < ActiveRecord::Migration[5.1]
  def change
    create_table :contacts do |t|
      t.string :sku
      t.string :phone
      t.string :email
      t.string :name
      t.string :city
      t.string :region
      t.text :own_comment
      t.string :action
      t.date :system_date
      t.string :state
      t.timestamps
    end
  end
end
