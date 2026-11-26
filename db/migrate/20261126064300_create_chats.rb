class CreateChats < ActiveRecord::Migration[8.1]
  def change
    create_table :chats do |t|
      t.jsonb :state, null: false, default: {}

      t.timestamps
    end
  end
end
