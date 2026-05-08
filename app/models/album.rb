class Album < ApplicationRecord
  enum :status, { draft: 0, public_album: 1, private_album: 2 }
  has_one_attached :cover_image
  has_many :photos, dependent: :destroy
  accepts_nested_attributes_for :photos, allow_destroy: true

  def self.create_album(album_params, photo_params)
    album = Album.new(album_params)
    album.published_at = Time.current
    album.save!

    photo_files = photo_params
    if photo_files.any?
      ActiveRecord::Base.transaction do
        photo_files.each do |photo_file|
          album.photos.create!(image: photo_file)
        end
      end
    end

    album
  end

  def self.update_album(album, photos_params)
    ActiveRecord::Base.transaction do
      album.update!(photos_params)
    end
    album
  end
end
