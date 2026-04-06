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
    if @album.save
      redirect_to @album, notice: "Album created successfully"
    end
  end
end
