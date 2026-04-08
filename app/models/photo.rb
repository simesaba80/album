class Photo < ApplicationRecord
  has_one_attached :image
  belongs_to :album
end
