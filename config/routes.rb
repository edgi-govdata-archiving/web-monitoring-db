Rails.application.routes.draw do
  root 'pages#index'
  resources :pages, path: '/pages'
end
