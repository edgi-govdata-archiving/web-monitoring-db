Rails.application.routes.draw do
  root 'home#index'

  devise_for :users, controllers: {
    registrations: 'users/registrations',
    sessions: 'users/sessions'
  }

  devise_scope :user do
    get 'users/session', to: 'users/sessions#validate_session'
  end

  namespace :api do
    namespace :v0 do
      # Add minimal login/session validation routes inside API namespace. These
      # are the same as the root `/users/*` routes listed above. This is to
      # make things easier for API clients (everything has the same base path).
      devise_scope :user do
        post 'users/sign_in', to: '/users/sessions#create'
        get 'users/session', to: '/users/sessions#validate_session'
      end

      resources :pages, only: [:index, :show], format: :json do
        get 'versions/sampled', to: 'versions#sampled'
        resources :versions, only: [:index, :show, :create]
        resources :changes,
          # Allow :id to be ":from_uuid..:to_uuid" or just ":change_id"
          constraints: { id: /(?:[\w\-]*\.\.[\w\-]+)|(?:[\w\-]+\.\.[\w\-]*)|(?:[^\.\/]+)/ },
          only: [:index, :show] do
            resources :annotations, only: [:index, :show, :create]
            member do
              get 'diff/:type', to: 'diff#show'
            end
        end
        resources :maintainers, except: [:new, :edit], format: :json
        resources :tags, except: [:new, :edit], format: :json
        resources :urls
      end

      resources :versions, only: [:index, :show], format: :json do
        get 'raw', on: :member, format: false
      end
      resources :imports, only: [:create, :show], format: :json
      resources :maintainers, except: [:new, :edit, :destroy], format: :json
      resources :tags, except: [:new, :edit, :destroy], format: :json
    end
  end

  namespace :admin do
    resources :users, only: [:edit, :update], path_names: { edit: '' }
  end

  get 'admin', to: 'admin#index'
  post 'admin/invite'
  get 'admin/invite', to: redirect('admin')
  delete 'admin/cancel_invitation'
  post 'admin/cancel_invitation'
  delete 'admin/destroy_user'
  post 'admin/destroy_user'

  get 'healthcheck', to: 'healthcheck#index'
end
