source "https://rubygems.org"

# Bundle edge Rails instead: gem "rails", github: "rails/rails", branch: "main"
gem "rails", "~> 8.1.4"
# Use postgresql as the database for Active Record
gem "pg", "~> 1.1"
# Use the Puma web server [https://github.com/puma/puma]
gem "puma", ">= 5.0"

# Use Active Model has_secure_password [https://guides.rubyonrails.org/active_model_basics.html#securepassword]
gem "bcrypt", "~> 3.1.22"

# Windows does not include zoneinfo files, so bundle the tzinfo-data gem
gem "tzinfo-data", platforms: %i[ windows jruby ]

# Use the database-backed adapters for Rails.cache, Active Job, and Action Cable
gem "solid_cache"
gem "solid_queue"
gem "solid_cable"

# Reduces boot times through caching; required in config/boot.rb
gem "bootsnap", require: false

# Deploy this application anywhere as a Docker container [https://kamal-deploy.org]
gem "kamal", require: false

# Add HTTP asset caching/compression and X-Sendfile acceleration to Puma [https://github.com/basecamp/thruster/]
gem "thruster", require: false

# Use Rack CORS for handling Cross-Origin Resource Sharing (CORS), making cross-origin Ajax possible
# gem "rack-cors"

group :development, :test do
  # See https://guides.rubyonrails.org/debugging_rails_applications.html#debugging-with-the-debug-gem
  gem "debug", platforms: %i[ mri windows ], require: "debug/prelude"

  # Audits gems for known security defects (use config/bundler-audit.yml to ignore issues)
  gem "bundler-audit", require: false

  # Static analysis for security vulnerabilities [https://brakemanscanner.org/]
  gem "brakeman", require: false

  # Omakase Ruby styling [https://github.com/rails/rubocop-rails-omakase/]
  gem "rubocop-rails-omakase", require: false
end

# API documentation (OpenAPI generated from request specs, Swagger UI at /api-docs)
gem "rswag-api", "~> 2.17"
gem "rswag-ui", "~> 2.17"

# Google and Microsoft sign-in
gem "omniauth", "~> 2.1"
gem "omniauth-google-oauth2", "~> 1.2"
gem "omniauth-entra-id", "~> 3.1"
gem "omniauth-rails_csrf_protection", "~> 2.0"

group :development, :test do
  gem "rspec-rails", "~> 8.0"
  gem "rswag-specs", "~> 2.17"
  gem "factory_bot_rails", "~> 6.5"
  gem "faker", "~> 3.8"
  gem "dotenv-rails", "~> 3.2"
end

group :development do
  # Preview sent emails at /letter_opener
  gem "letter_opener_web", "~> 3.0"
end

group :test do
  gem "shoulda-matchers", "~> 8.0"
  gem "simplecov", "~> 1.3", require: false
  gem "webmock", "~> 3.34"
end

gem "nokogiri", "~> 1.19"
