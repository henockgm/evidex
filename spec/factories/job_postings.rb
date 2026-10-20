FactoryBot.define do
  factory :job_posting do
    user
    title { "Senior Ruby on Rails Developer" }
    company { "Acme Oy" }
    location { "Helsinki, Finland" }
    work_model { "hybrid" }
    deadline { 3.weeks.from_now.to_date }
    source_url { "https://jobs.example.com/acme/rails-developer" }
    description { "We are looking for a Rails developer with PostgreSQL and RSpec experience." }
  end
end
