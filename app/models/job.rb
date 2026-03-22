class Job < ApplicationRecord
  belongs_to :pipeline

  enum :status, { pending: 0, running: 1, success: 2, failed: 3 }

  validates :name, presence: true
end
