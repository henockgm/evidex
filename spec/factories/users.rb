FactoryBot.define do
  factory :user do
    sequence(:email_address) { |n| "user#{n}@example.com" }
    name { Faker::Name.name }
    password { "correct horse battery staple" }
    email_verified_at { Time.current }

    trait :unverified do
      email_verified_at { nil }
    end

    trait :two_factor do
      after(:create) do |user|
        user.update!(otp_secret: ROTP::Base32.random, otp_enabled_at: Time.current)
        RecoveryCode.regenerate_for!(user)
      end
    end

    # Admins need two-factor sign-in to use the admin area.
    trait :admin do
      admin { true }
      two_factor
    end

    trait :oauth_only do
      password { nil }
      after(:create) { |user| create(:identity, user:) }
    end
  end

  factory :identity do
    user
    provider { "google_oauth2" }
    sequence(:uid) { |n| "google-uid-#{n}" }
    email { user.email_address }
    email_verified { true }
  end

  factory :session do
    user
    ip_address { "127.0.0.1" }
    user_agent { "RSpec" }
  end
end
