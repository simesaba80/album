class CreateAlbums < ActiveRecord::Migration[8.1]
  def change
    create_table :albums do |t|
      t.string :title
      t.text :description
      t.integer :status
      t.datetime :published_at

      t.timestamps

      add_index :albums, :status
    end
  end
end
