class AlbumsController < ApplicationController
  def index
    @albums = Album.all

    render json: @albums.map { |album| get_cover_image(album) }
  end

  def show
    @album = Album.find(params[:id])
    response = get_photos(@album)
    render json: response
  end

  def create
    @album = Album.new(album_params)
    @album.published_at = Time.current
    if @album.save
      render json: @album, status: :created
    else
      render json: @album.errors, status: :unprocessable_entity
    end

    photo_files = photo_params
    if photo_files.any?
      ActiveRecord::Base.transaction do
        photo_files.each do |photo_file|
          photo = @album.photos.create!(image: photo_file)
          photo.image.attach(photo_file)
        end
      end

      render json: @album, status: :created
    else
      render json: @album.errors, status: :unprocessable_entity
    end
  end

  private
    def album_params
      params.expect(album: [ :title, :cover_image, :description, :status ])
    end

    def photo_params
      Array(params.dig(:album, :photo_images))
    end

    def get_cover_image(album)
      album.as_json.merge(
        cover_image_url: album.cover_image.attached? ? url_for(album.cover_image) : nil
      )
    end

    def get_photos(album)
      album.as_json.merge(
        photos: album.photos.map do |photo|
          photo.as_json.merge(
            image_url: photo.image.attached? ? url_for(photo.image) : nil
          )
        end
      )
    end
end
