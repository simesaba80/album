class AlbumsController < ApplicationController
  def index
    @albums = Album.all

    render json: @albums
  end

  def show
    @album = Album.find(params[:id])

    render json: @album
  end

  def new
    @album = Album.new

    render json: @album
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
end
