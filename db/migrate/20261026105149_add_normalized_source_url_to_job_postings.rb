# The ad link in comparable form (see AdLink), indexed per user so saving a
# posting can quickly find the same ad saved before.
class AddNormalizedSourceUrlToJobPostings < ActiveRecord::Migration[8.1]
  class Posting < ActiveRecord::Base
    self.table_name = "job_postings"
  end

  def up
    add_column :job_postings, :normalized_source_url, :string
    add_index :job_postings, %i[user_id normalized_source_url]

    Posting.where.not(source_url: nil).find_each do |posting|
      posting.update_columns(normalized_source_url: AdLink.normalize(posting.source_url))
    end
  end

  def down
    remove_column :job_postings, :normalized_source_url
  end
end
