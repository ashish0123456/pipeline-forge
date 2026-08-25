class ApiToken < ApplicationRecord
  belongs_to :user

  attr_reader :raw_token
  validates :name, presence: true

  def self.issue!(user, name:, expires_at: nil)
    raw_token = SecureRandom.urlsafe_base64(32)
    token = create!(user: user, name: name, token_digest: digest(raw_token), expires_at: expires_at)
    token.instance_variable_set(:@raw_token, raw_token)
    token
  end

  def self.authenticate(raw_token)
    return if raw_token.blank?

    find_by(token_digest: digest(raw_token))&.then do |token|
      next if token.expires_at&.past?

      token.update_column(:last_used_at, Time.current)
      token.user
    end
  end

  def self.digest(raw_token)
    Digest::SHA256.hexdigest(raw_token)
  end
end
