# Operators of the instance. Set only from the server console or rake
# (evidex:admin:grant), never through the API.
class AddAdminToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :admin, :boolean, default: false, null: false
  end
end
