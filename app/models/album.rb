class Album < ApplicationRecord
  enum :status, { draft: 0, public_album: 1, private_album: 2 }
  has_one_attached :cover_image
  has_many :photos, dependent: :destroy

  def self.create_album(album_params, photo_params)
    album = Album.new(album_params)
    album.published_at = Time.current
    if !album.save
      raise album.errors
    end

    photo_files = photo_params
    if photo_files.any?
      ActiveRecord::Base.transaction do
        photo_files.each do |photo_file|
          if !album.photos.create!(image: photo_file)
            raise album.errors
          end
        end
      end
    end

    album
  end
end
