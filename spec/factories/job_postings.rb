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

FactoryBot.define do
  factory :requirement do
    job_posting
    kind { "required" }
    sequence(:text) { |n| "Requirement #{n}" }
  end
end

FactoryBot.define do
  factory :application_contact do
    job_application { create(:job_posting).job_application } # created with the posting
    name { "Ana Virtanen" }
    role { "Recruiter" }
    email { "ana@example.com" }
  end
end

FactoryBot.define do
  factory :interview do
    job_application { create(:job_posting).job_application }
    round { "1st round" }
    scheduled_at { 3.days.from_now.change(hour: 14) }
    format { "video" }
  end
end
