# An admin lock (ADM-01): unlike locked_until (a temporary lock after failed
# sign-ins), it lasts until an admin lifts it and blocks every way of signing in.
class AddSuspendedAtToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :suspended_at, :datetime
  end
end
