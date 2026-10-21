class CreateDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :documents do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.string :title, null: false
      t.string :kind, null: false, default: "cv" # cv, project, certificate, reference, other
      t.boolean :primary, null: false, default: false # the user's main CV
      t.string :status, null: false, default: "pending" # pending, processing, ready, failed
      t.string :error

      t.timestamps
    end
    add_index :documents, %i[user_id created_at]
    # At most one primary CV per user.
    add_index :documents, :user_id, unique: true, where: '"primary"', name: "index_documents_one_primary_per_user"
  end
end
