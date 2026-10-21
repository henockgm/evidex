FactoryBot.define do
  factory :document do
    user
    title { "My CV" }
    kind { "cv" }

    transient do
      fixture { "cv.pdf" }
    end

    after(:build) do |document, context|
      path = Rails.root.join("spec/fixtures/files", context.fixture)
      document.file.attach(io: File.open(path), filename: context.fixture, identify: true)
    end
  end
end
