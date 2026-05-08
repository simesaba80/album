class AlbumsController < ApplicationController
  def index
    @albums = Album.all

    render json: @albums.map { |album| get_cover_image(album) }
  rescue => e
    render json: { error: e.message }, status: :internal_server_error
  end

  def show
    @album = Album.find(params[:id])
    response = get_photos(@album)
    if response.nil?
      return render json: { error: "Album not found" }, status: :not_found
    end
    render json: response, status: :ok
  end

  def create
    @album = Album.create_album(album_params)
    render json: get_photos(@album), status: :created
  end

  def update
    @album = Album.find(params[:id])
    @album = Album.update_album(@album, photos_params)
    render json: get_photos(@album), status: :ok
  end

  def destroy
    @album = Album.find(params[:id])
    @album.destroy!
    render json: { message: "Album deleted successfully" }, status: :ok
  end

  private
    def album_params
      params.expect(album: [
        :title,
        :cover_image,
        :description,
        :status,
        photos_attributes: [ [
          :id, :image, :caption, :display_order
        ] ]
      ])
    end

    def photo_params
      Array(params.dig(:album, :photo_images))
    end

    def photos_params
      params.require(:album).permit(
        :title,
        :cover_image,
        :description,
        :status,
        photos_attributes: [ :id, :image, :caption, :display_order, :_destroy ]
      )
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
