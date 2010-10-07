ActionController::Routing::Routes.draw do |map|
  devise_for :users

  scope ":locale" do
    resources :users
    
    resources :skills do
      member do 
        get 'prereqs'
        get 'future'
      end
    end
    
    resources :curriculums do
      member do
        get 'cycles'
      end
    end
    
    resource :plan do
      resources :profiles, :controller => 'plans/profiles', :except => [:new, :edit, :update]
      resources :courses, :controller => 'plans/courses'
    end
    
    scope "/:curriculum_id" do
      resources :courses do
        member do
          get 'graph'
        end
      end
      
      resources :profiles do
        resources :courses, :controller => 'profiles/courses'
      end
    end
    
  end
  
  
  #map.resource :session
  #match 'login' => 'sessions#new', :as => :login
  #match 'logout' => 'sessions#destroy', :as => :logout


  # The priority is based upon order of creation: first created -> highest priority.

  # Sample of regular route:
  #   map.connect 'products/:id', :controller => 'catalog', :action => 'view'
  # Keep in mind you can assign values other than :controller and :action

  # Sample of named route:
  #   map.purchase 'products/:id/purchase', :controller => 'catalog', :action => 'purchase'
  # This route can be invoked with purchase_url(:id => product.id)

  # Sample resource route (maps HTTP verbs to controller actions automatically):
  #   map.resources :products

  # Sample resource route with options:
  #   map.resources :products, :member => { :short => :get, :toggle => :post }, :collection => { :sold => :get }

  # Sample resource route with sub-resources:
  #   map.resources :products, :has_many => [ :comments, :sales ], :has_one => :seller
  
  # Sample resource route with more complex sub-resources
  #   map.resources :products do |products|
  #     products.resources :comments
  #     products.resources :sales, :collection => { :recent => :get }
  #   end
  
  

  # Sample resource route within a namespace:
  #   map.namespace :admin do |admin|
  #     # Directs /admin/products/* to Admin::ProductsController (app/controllers/admin/products_controller.rb)
  #     admin.resources :products
  #   end

  # You can have the root of your site routed with map.root -- just remember to delete public/index.html.
  root :to => "frontpage#index"
  map.frontpage '/:locale', :controller => 'frontpage'

  # See how all your routes lay out with "rake routes"

  # Install the default routes as the lowest priority.
  # Note: These default routes make all actions in every controller accessible via GET requests. You should
  # consider removing or commenting them out if you're using named routes and resources.
  #map.connect ':controller/:action/:id'
  #map.connect ':controller/:action/:id.:format'
end
