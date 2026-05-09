class Album < ApplicationRecord
  enum :status, { draft: 0, public_album: 1, private_album: 2 }
  has_one_attached :cover_image
  has_many :photos, -> { order(display_order: :desc) }, dependent: :destroy
  # accepts_nested_attributes_for :photos, allow_destroy: true

  def self.create_album(album_params)
    album = Album.new(album_params)
    album.published_at = Time.current
    album.save!
    album
  end

  def self.create_album_with_photos(payload)
    album_attrs = payload[:album] || {}
    photos_attrs = payload.dig(:photos, :create) || []

    transaction do
      album = Album.new(album_attrs)
      album.published_at = Time.current

      photos_attrs.each do |photo_attrs|
        album.photos.build(
          image: photo_attrs[:image],
          caption: photo_attrs[:caption],
          display_order: photo_attrs[:display_order]
        )
      end

      album.save!
      album
    end
  end


  def self.update_album(album, photos_params)
    ActiveRecord::Base.transaction do
      album.update!(photos_params)
    end
    album
  end

  def self.update_album_with_photos(album, payload)
    album_attrs = payload[:album] || {}
    photos_attrs_to_create = payload.dig(:photos, :create) || []
    photos_attrs_to_update = payload.dig(:photos, :update) || []
    photos_to_destroy = payload.dig(:photos, :destroy) || []

    transaction do
      album.update!(album_attrs)
      photos_attrs_to_create.each do |photo_attrs|
        album.photos.create!(
          image: photo_attrs[:image],
          caption: photo_attrs[:caption],
          display_order: photo_attrs[:display_order]
        )
      end

      photos_attrs_to_update.each do |photo_attrs|
        photo = album.photos.find(photo_attrs[:id])
        photo.update!(
          caption: photo_attrs[:caption],
          display_order: photo_attrs[:display_order]
        )
      end

      photos_to_destroy.each do |photo_id|
        photo = album.photos.find(photo_id[:id])
        photo.destroy!
      end

      album
    end
  end
end
