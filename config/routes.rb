require "sidekiq/web"
require "sidekiq/cron/web"

Rails.application.routes.draw do
  # Control panel (/admin)
  devise_for :admin_users, ActiveAdmin::Devise.config
  ActiveAdmin.routes(self)
  mount Sidekiq::Web => "/admin/sidekiq"

  # Resources
  resources :areas, only: [:show] do
    resources :alerts, only: [:create] do
      collection do
        get "unsubscribe", to: "alerts#unsubscribe"
        get "confirm", to: "alerts#confirm"
      end
    end
  end
  resources :search, only: [:index]

  # Root
  root to: "home#index"
end
