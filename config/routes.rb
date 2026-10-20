Rails.application.routes.draw do
  mount Rswag::Ui::Engine => "/api-docs"
  mount Rswag::Api::Engine => "/api-docs"
  mount LetterOpenerWeb::Engine, at: "/letter_opener" if Rails.env.development?

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  namespace :api do
    namespace :v1 do
      resource :status, only: :show
      resource :csrf_token, only: :show
      get "auth/providers", to: "auth_providers#index", as: :auth_providers

      resource :registration, only: :create
      resource :session, only: %i[create destroy]
      resource :email_verification, only: :create do
        post :resend
      end
      resource :password_reset, only: %i[create update]

      resource :job_posting_import, only: :create
      resources :job_postings, only: %i[index show create update destroy] do
        resources :requirements, only: %i[create update destroy], shallow: true
      end

      resource :me, only: %i[show destroy], controller: "me" do
        scope module: :me do
          resources :sessions, only: %i[index destroy] do
            delete :others, on: :collection, action: :destroy_others
          end
          resources :identities, only: %i[index destroy]
          resource :password, only: :update
        end
      end
    end
  end

  # OmniAuth handles POST /auth/:provider itself and redirects to the provider.
  match "/auth/:provider/callback", to: "omniauth_callbacks#create", via: %i[get post], as: :oauth_callback
  get "/auth/failure", to: "omniauth_callbacks#failure"
end
