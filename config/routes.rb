Rails.application.routes.draw do
  get "/up", to: "health#check"
  get "/login", to: "sessions#new"
  post "/login", to: "sessions#create"
  delete "/logout", to: "sessions#destroy"
  namespace :api do
    namespace :v1 do
      resources :api_tokens, only: :create, controller: "api_tokens"
      resources :projects, only: [] do
        resources :pipelines, only: [] do
          resources :pipeline_runs, only: [:index, :show], controller: "pipeline_runs" do
            member { post :retry }
            resources :execution_logs, only: :index, controller: "execution_logs"
          end
        end
      end
    end
  end
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
