class CreatePhotos < ActiveRecord::Migration[8.1]
  def change
    create_table :photos do |t|
      t.string :caption
      t.integer :display_order, default: 0
      t.datetime :shot_at

      t.timestamps

      t.index :display_order
    end
  end
end
