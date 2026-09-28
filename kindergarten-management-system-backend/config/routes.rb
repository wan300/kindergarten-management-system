Rails.application.routes.draw do
  resources :attendances, only: [:index,:create]
  resources :disciplines,only: [:index, :show, :create, :update, :destroy]
  resources :parent_students, only: [:index, :create]
  resources :parents,only: [:index, :show, :create]
  resources :students
  resources :teachers,only: [:show]
  resources :classrooms, only: [:index, :show]
  post '/login', to: 'auth#create'
  post '/parent_login', to: 'parent_auth#create'
  post '/child_login', to: 'child_auth#create'
  post '/admin_login', to: 'admin_auth#create'
  get '/profile', to: 'teachers#profile'
  get 'teacher/parent/', to: 'teachers#classroom_parents'
  resources :growth_records, only: [:index, :create]

  scope path: :admin, module: :admin_api, as: :admin do
    get '/profile', to: 'admins#profile'
    get '/summary', to: 'summary#index'
    resources :admins
    resources :teachers
    resources :classrooms
    resources :classroom_imports, only: [:create] do
      collection do
        get :template
        post :preview
      end
    end
    resources :students
    resources :parents
    resources :parent_students, only: [:index, :create, :update, :destroy]
    resources :attendances, only: [:index, :destroy]
    resources :disciplines, only: [:index, :show, :create, :update, :destroy]
    resources :growth_records, only: [:index, :create, :update, :destroy]
    resources :educational_videos
    resources :child_devices, only: [:index] do
      collection { post :bind }
      member do
        patch :disable
        patch :enable
      end
    end
    resources :child_chat_sessions, only: [:index, :show]
    get '/parenting_advice/recipient_options', to: 'parenting_advice#recipient_options'
    resources :external_email_recipients
    resources :parenting_advice_schedules, only: [:index, :show, :create, :destroy] do
      member do
        patch :pause
        patch :resume
      end
    end
  end

  scope path: :child, module: :child_api, as: :child do
    get '/profile', to: 'students#show'
    get '/students', to: 'students#index'
    get '/videos', to: 'videos#index'
    post '/tts', to: 'tts#create'
    resources :chat_sessions, only: [:index, :show, :create] do
      resources :messages, only: [:create], controller: :chat_messages
    end
  end

  scope path: :device, module: :device_api, as: :device do
    post '/registration', to: 'registrations#create'
    resources :turns, only: [:create]
  end

  scope path: :parent, module: :parent_api, as: :parent_api do
    get '/children', to: 'children#index'
    get '/children/:student_id/chat_sessions', to: 'children#chat_sessions'
    patch '/children/:student_id/password', to: 'children#update_password'
  end
  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Defines the root path route ("/")
  # root "articles#index"
end
