Rails.application.routes.draw do
  devise_for :users
  root 'pages#index'
  resources :pages, path: '/pages'
end
