# Marks the one shared demo account (see Demo::Account). The partial unique
# index makes sure there is never more than one.
class AddDemoToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :demo, :boolean, default: false, null: false
    add_index :users, :demo, unique: true, where: "demo"
  end
end
