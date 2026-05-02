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
    @album = Album.create_album(album_params, photo_params)
    render json: get_photos(@album), status: :created
  end

  def update
    @album = Album.find(params[:id])
    @album = Album.update_album(@album, photos_params)
    render json: get_photos(@album), status: :ok
  end

  def destroy
    @album = Album.find(params[:id])
    if !@album.destroy
      raise "Failed to delete album"
    end
    render json: { message: "Album deleted successfully" }, status: :ok
  end

  private
    def album_params
      params.expect(album: [ :title, :cover_image, :description, :status ])
    end

    def photo_params
      Array(params.dig(:album, :photo_images))
    end

    def photo_changes_params
      raw = params.fetch(:photo_changes, {})
      add_rows = Array(raw[:add]&.values).map { |p| p.permit(:image, :caption, :display_order) }
      update_rows = Array(raw[:update]&.values).map { |p| p.permit(:id, :image, :caption, :display_order) }
      delete_ids = Array(raw[:delete_ids])

      {
        add: add_rows,
        update: update_rows,
        delete_ids: delete_ids
      }
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
