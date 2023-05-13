require "sidekiq/web"
require "sidekiq/cron/web"

Rails.application.routes.draw do
  # Control panel
  devise_for :admin_users, ActiveAdmin::Devise.config
  authenticate :admin_user do
    ActiveAdmin.routes(self)
    mount Sidekiq::Web => "/#{ENV.fetch("ADMIN_PATH", "admin")}/sidekiq"
  end

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

  # Static pages
  get "about", to: 'about#show'
  get "privacy_policy", to: 'privacy_policy#show'

  # Root
  root to: "home#index"
end
