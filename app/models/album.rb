class Album < ApplicationRecord
  enum :status, { draft: 0, public_album: 1, private_album: 2 }
  has_one_attached :cover_image
end
