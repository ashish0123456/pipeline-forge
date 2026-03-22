class Project < ApplicationRecord
  validates :name, presence: true
  validates :repository_url, presence: true, format: { with: URI::regexp(%w[http https]) }

  has_many :pipelines, dependent: :destroy
end
