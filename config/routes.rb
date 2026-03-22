Rails.application.routes.draw do
  root "projects#index"
  resources :projects do
    resources :pipelines do
      member do
        post :run
      end
      resources :jobs
    end
  end
end
