class AlbumsController < ApplicationController
  allow_unauthenticated_access
  def index
    @albums = Album.all
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
  end

  private
    def album_params
      params.expect(album: [ :title, :cover_image, :description, :status ])
    end
end
