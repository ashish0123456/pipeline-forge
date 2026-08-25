class ExecutionLog < ApplicationRecord
  belongs_to :job_run

  validates :sequence, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :content, presence: true
end
