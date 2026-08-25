class User < ApplicationRecord
  has_secure_password
  has_many :project_memberships, dependent: :destroy
  has_many :projects, through: :project_memberships
  has_many :api_tokens, dependent: :destroy
  has_many :audit_events, dependent: :nullify

  enum :role, { member: "member", admin: "admin" }

  normalizes :email, with: ->(email) { email.strip.downcase }
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }, uniqueness: { case_sensitive: false }
end
