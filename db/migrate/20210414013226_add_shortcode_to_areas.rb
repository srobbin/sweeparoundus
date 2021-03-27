class AddShortcodeToAreas < ActiveRecord::Migration[6.1]
  def change
    add_column :areas, :shortcode, :string
    add_index :areas, :shortcode, unique: true
  end
end
