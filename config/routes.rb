Rails.application.routes.draw do
  root "conversations#index"

  resources :conversations, only: %i[index show create destroy] do
    resources :messages, only: %i[create]
  end

  namespace :api do
    namespace :v1 do
      resources :conversations, only: %i[index show create] do
        resources :messages, only: %i[create]
      end
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
