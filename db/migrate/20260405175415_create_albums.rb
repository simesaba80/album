class CreateAlbums < ActiveRecord::Migration[8.1]
  def change
    create_table :albums do |t|
      t.string :title
      t.text :description
      t.integer :status, null: false
      t.datetime :published_at

      t.timestamps

      add_index :albums, :status
    end
  end
end
