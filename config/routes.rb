Rails.application.routes.draw do
  devise_for :users
  
  
 # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  get "up" => "rails/health#show", as: :rails_health_check

  root "stores#index"

  resources :aisles, only: [:index]
  
  resources :stores, shallow: true do
    member do
      post :import_pairs_csv
    end
    get :aisles, on: :member
    resources :articles do
      collection do
        get :altered_articles
        get :unplanned_articles
        get :planned_articles
        get  :new_import
        delete :destroy_all
        post :import
      end
    end
    resources :pairs,shallow: true do
      resources :aisles, shallow: true do    
        # REMOVED: The previous 'member do... end' block.
        resources :sections, shallow: true do 
          collection do
            post :plan  
          end
          collection do
            get :export_csv
          end
          resources :levels
        end
      end
    end
            
  end

  # NEW FIX: Explicitly map the bulk unassign path to the SectionsController.
  # The URL path remains the same, but the request goes to the correct controller.
  patch 'aisles/:id/bulk_unassign', to: 'sections#bulk_unassign', as: :bulk_unassign_aisle
  
  # Existing: Route for unassigning a single article
  patch 'articles/:id/unassign', to: 'sections#unassign', as: :unassign_article
end