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

  def self.update_album_old(album, album_params, photo_changes_params)
    ActiveRecord::Base.transaction do
      album.update!(album_params)
      puts "--------------------------------"
      puts photo_changes_params
      puts "--------------------------------"

      Array(photo_changes_params[:delete_ids]).each do |photo_id|
        album.photos.find(photo_id).destroy!
      end

      Array(photo_changes_params[:add]).each do |photo_change|
        image = photo_change[:image]
        next if image.blank?
        album.photos.create!(image: image)
      end

      Array(photo_changes_params[:update]).each do |photo_change|
        # findはActiveRecord::RecordNotFoundをraiseする
        photo = album.photos.find(photo_change[:id])

        photo.image.attach(photo_change[:image]) if photo_change[:image].present?
        attr = {} # 更新する属性を格納するハッシュ
        attr[:caption] = photo_change[:caption] if photo_change.key?(:caption)
        attr[:display_order] = photo_change[:display_order] if photo_change.key?(:display_order)
        photo.update!(attr) if attr.any?
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
