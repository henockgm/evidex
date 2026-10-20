# A linked Google or Microsoft account.
class Identity < ApplicationRecord
  PROVIDERS = %w[google_oauth2 entra_id].freeze

  belongs_to :user

  normalizes :email, with: ->(email) { email.strip.downcase }

  validates :provider, inclusion: { in: PROVIDERS }, uniqueness: { scope: :user_id }
  validates :uid, presence: true, uniqueness: { scope: :provider }

  def label
    Evidex::OAUTH_PROVIDERS.dig(provider.to_sym, :label)
  end
end
