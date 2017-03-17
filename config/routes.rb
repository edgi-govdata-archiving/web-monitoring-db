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

  namespace :api do
    namespace :v1 do
      resources :pages, only: [:index, :show], format: :json do
        resources :versions, only: [:index, :show] do
          resources :changes, only: [:index, :show] do
            resources :annotations, only: [:index, :show, :create]
          end
          resources :annotations, only: [:index, :show, :create]
        end
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
