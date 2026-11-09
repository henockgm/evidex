# Ads in other languages are read into English; the ad's language and each
# requirement's original wording are kept alongside.
class AddLanguageToPostingsAndSourceTextToRequirements < ActiveRecord::Migration[8.1]
  def change
    add_column :job_postings, :language, :string
    add_column :requirements, :source_text, :text
  end
end
