# When the user last proved who they are on this device: at sign-in, and again
# when they re-authenticate before a sensitive change ("sudo mode").
class AddAuthenticatedAtToSessions < ActiveRecord::Migration[8.1]
  def change
    add_column :sessions, :authenticated_at, :datetime

    reversible do |direction|
      direction.up { execute "UPDATE sessions SET authenticated_at = created_at" }
    end

    change_column_null :sessions, :authenticated_at, false
  end
end
