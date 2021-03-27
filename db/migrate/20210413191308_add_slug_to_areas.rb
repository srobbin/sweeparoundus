class AddSlugToAreas < ActiveRecord::Migration[6.1]
  def change
    add_column :areas, :slug, :string
    add_index :areas, :slug, unique: true
  end
end
