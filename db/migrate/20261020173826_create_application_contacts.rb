class CreateApplicationContacts < ActiveRecord::Migration[8.1]
  def change
    create_table :application_contacts do |t|
      t.references :job_application, null: false, foreign_key: { on_delete: :cascade }
      t.string :name, null: false
      t.string :role # e.g. recruiter, hiring manager
      t.string :email
      t.string :phone
      t.text :notes

      t.timestamps
    end
  end
end
