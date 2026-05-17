Rails.application.routes.draw do
  root "conversations#index"

  resource :session, only: %i[new create destroy]

  # Bootstrap del primer admin desde el browser. Solo accesible si la DB
  # está vacía — después de eso, redirige al login.
  get  "/setup", to: "setup#new",    as: :setup
  post "/setup", to: "setup#create"

  resources :conversations, only: %i[index show create update destroy] do
    resources :messages, only: %i[create] do
      collection { post :transcribe }
    end
  end

  # Settings: una sola página admin-only con contexto del asistente + users.
  # Devices vive aparte (es la feature estrella, ruta principal).
  resource  :settings, only: %i[show update]
  resources :users,    only: %i[create update destroy] do
    member { post :regenerate_token }
  end

  resources :memories, only: %i[index destroy]
  resource  :timezone, only: %i[update], controller: "timezone"
  resources :devices,  only: %i[index create update destroy] do
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
      resources :memories, only: %i[index destroy]
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
