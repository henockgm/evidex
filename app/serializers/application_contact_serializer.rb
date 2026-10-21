class ApplicationContactSerializer
  def initialize(contact)
    @contact = contact
  end

  def as_json(*)
    @contact.slice(:id, :name, :role, :email, :phone, :notes).symbolize_keys
  end
end
