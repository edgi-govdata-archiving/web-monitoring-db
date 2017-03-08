Rails.application.routes.draw do
  root 'pages#index'

  devise_for :users, controllers: {
    registrations: 'users/registrations'
  }

  resources :pages, path: '/pages', only: [:index, :show] do
    resources :versions, only: [:index, :show] do
      member do
        get 'annotations'
        post 'annotations', action: 'annotate'
      end
    end
  end

  get 'admin', to: 'admin#index'
  post 'admin/invite'
  get 'admin/invite', to: redirect('admin')
  delete 'admin/cancel_invitation'
  post 'admin/cancel_invitation'
  delete 'admin/destroy_user'
  post 'admin/destroy_user'
end
