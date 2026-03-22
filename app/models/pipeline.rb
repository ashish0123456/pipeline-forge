class Pipeline < ApplicationRecord
  belongs_to :project
  has_many :jobs, dependent: :destroy

  enum :status, { pending: 0, running: 1, success: 2, failed: 3 }

  validates :name, presence: true
end
