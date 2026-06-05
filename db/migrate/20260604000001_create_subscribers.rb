class CreateSubscribers < ActiveRecord::Migration[8.1]
  def change
    create_table :subscribers, id: :uuid do |t|
      t.string :email, null: false

      t.timestamps
    end

    add_index :subscribers, :email, unique: true
  end
end
