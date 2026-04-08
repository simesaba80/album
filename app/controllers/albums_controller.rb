class AlbumsController < ApplicationController
  allow_unauthenticated_access
  def index
    @albums = Album.all
  end

  def show
    @album = Album.find(params[:id])
  end

  def new
    @album = Album.new
  end

  def create
    @album = Album.new(album_params)
    @album.published_at = Time.current
    if @album.save
      redirect_to albums_path, notice: "Album created successfully"
    end

    photo_files = photo_params
    if photo_files.any?
      ActiveRecord::Base.transaction do
        photo_files.each do |photo_file|
          photo = @album.photos.create!(image: photo_file)
          photo.image.attach(photo_file)
        end
      end
    end
  end

  private
    def album_params
      params.expect(album: [ :title, :cover_image, :description, :status ])
    end

    def photo_params
      Array(params.dig(:album, :photo_images))
    end
end
