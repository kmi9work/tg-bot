class AddAasmStateToContactChats < ActiveRecord::Migration[5.1]
  def change
    add_column :contact_chats, :aasm_state, :string
  end
end
