Rails.application.routes.draw do
  root "conversations#index"

  resources :conversations, only: %i[index show create update destroy] do
    resources :messages, only: %i[create]
  end

  resources :model_configs, only: %i[index update]
  resources :devices, only: %i[index create update destroy] do
    member do
      post :regenerate_token
      post :command
    end
  end

  namespace :api do
    namespace :v1 do
      resources :conversations, only: %i[index show create destroy] do
        resources :messages, only: %i[create] do
          collection { post :stream, to: "message_streams#create" }
        end
      end
      resources :models,  only: %i[index]
      resources :devices, only: %i[index create update destroy] do
        member do
          post :regenerate_token
          post :command
        end
      end
      resource :action,    only: %i[create]
      resource :heartbeat, only: %i[create]
    end
  end

  get "up" => "rails/health#show", as: :rails_health_check
end
