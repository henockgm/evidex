class KnownDevice < ApplicationRecord
  belongs_to :user

  # Remembers the browser behind this device token; true when the user has
  # signed in from other browsers before but never from this one.
  def self.new_for?(user, token, request)
    device = user.known_devices.find_or_initialize_by(device_digest: OpenSSL::Digest::SHA256.hexdigest(token))
    first_time = device.new_record?
    device.update!(last_seen_at: Time.current, user_agent: request.user_agent&.first(255), ip_address: request.remote_ip)
    first_time && user.known_devices.where.not(id: device.id).exists?
  end
end
