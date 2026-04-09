require "sidekiq/web"
require "sidekiq/cron/web"

Rails.application.routes.draw do
  # Control panel
  devise_for :admin_users, ActiveAdmin::Devise.config
  authenticate :admin_user do
    ActiveAdmin.routes(self)
    mount Sidekiq::Web => "/#{ENV.fetch("ADMIN_PATH", "admin")}/sidekiq"
  end

  # API
  namespace :api do
    namespace :v1 do
      resources :sweeps, only: [:index]
    end
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

  # Subscription management
  get "subscriptions", to: "subscriptions#new"
  post "subscriptions/send_link", to: "subscriptions#send_link", as: :subscriptions_send_link
  get "subscriptions/manage", to: "subscriptions#show", as: :manage_subscriptions
  post "subscriptions", to: "subscriptions#create", as: :create_subscription
  patch "subscriptions/:id/confirm", to: "subscriptions#confirm", as: :confirm_subscription
  delete "subscriptions/:id", to: "subscriptions#destroy", as: :destroy_subscription

  # Static pages
  get "about", to: 'about#show'
  get "privacy_policy", to: 'privacy_policy#show'

  # Root
  root to: "home#index"
end
