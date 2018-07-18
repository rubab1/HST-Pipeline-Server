Rpipeline::Application.routes.draw do

  resources :events do 
    resources :options
  end
  
  match '/pipelines/get_aws_credentials/:pipeline_id.:format', :controller => "pipelines", :action => "get_aws_credentials", :via => [ :get, :post ]
    
  resources :pipelines do 
    resources :tasks, :targets, :nodes
  end

  get '/pipelines/:id/dpbypath(.:format)', to: "pipelines#dpbypath", as: 'dpbypath_pipeline'
  resources :pipelines, :member => { :dpbypath => :get}
  
  resources :pipelines, :member => { :create => :post}


  resources :tasks do 
    resources :masks, :jobs, :options
  end

  get '/tasks/:id/addjob(.:format)', to: 'tasks#addjob', as: 'addjob_task'
  get '/tasks/:id/add_requirement(.:format)', to: 'tasks#add_requirement', as: 'add_requirement_task'
  resources :tasks, :member => { :addjob => :get, :add_requirement => :get}

  get '/tasks/0/findbyname(.:format)', to: 'tasks#findbyname'
  get '/tasks/:id/findbyname(.:format)', to: 'tasks#findbyname', as: 'findbyname_task'
  resources :tasks, :member => { :findbyname => :get}

  resources :targets do 
    resources :configurations do
      resources :data_products
    end
  end

  post '/targets/:id/startjob(.:format)', to: 'targets#startjob', as: 'startjob_target'
  get '/targets/:id/cloneconfiguration(.:format)', to: 'targets#cloneconfiguration', as: 'cloneconfiguration_target'
  resources :targets, :member => { :startjob => :post, :cloneconfiguration => :get}

  get '/data_products/getuniquefilters/0(.:format)', to: 'data_products#getuniquefilters'
  post '/data_products/:id/findbyparameters(.:format)', to: 'data_products#findbyparameters' , as: 'findbyparameters_data_product'
  post '/data_products/:id/create_or_update(.:format)', to: 'data_products#create_or_update' , as: 'create_or_update_data_product'
  get '/data_products/:id/getuniquefilters(.:format)', to: 'data_products#getuniquefilters' , as: 'getuniquefilters_data_product'
  get '/data_products/:id/lock(.:format)', to: 'data_products#lock' , as: 'lock_data_product'
  get '/data_products/:id/unlock(.:format)', to: 'data_products#unlock' , as: 'unlock_data_product'
  resources :data_products, :member => { :findbyparameters => :post, :create_or_update => :post, :getuniquefilters => :get, :lock => :get, :unlock => :get}

  post '/tasks/:id/startjob(.:format)', to: 'tasks#startjob', as: 'startjob_task'
  get '/tasks/:id/unmask(.:format)', to: 'tasks#unmask', as:'unmask_task'
  resources :tasks, :member => { :startjob => :post, :unmask => :get}

  post '/nodes/:id/invoke(.:format)', to: 'nodes#invoke', as: 'invoke_node'
  resources :nodes, :member => { :invoke => :post}

  get '/configurations/:id/dataproducts(.:format)', to: 'configurations#dataproducts', as: 'dataproducts_configuration'
  get '/configurations/:id/getparameter(.:format)', to: 'configurations#getparameter', as: 'getparameter_configuration'
  resources :configurations, :member => { :dataproducts => :get, :getparameter => :get }
 
  resources :jobs do
    resources :events, :options
  end

  resources :nodes do
    resources :jobs
  end

  get '/events/:id/fire(.:format)', to: 'events#fire', as: 'fire_event'
  resources :events, :member =>{:fire => :get}
  
  resources :options

  resources :configurations do
    resources :parameters, :data_products
  end

  get '/users/login' => 'users#login'
  get '/users/logout' => 'users#logout'
  post '/users/logout' => 'users#logout'
  post '/users/login/' => 'users#login'
  get '/users/do_update' => 'users#do_update'
  post '/users/do_update' => 'users#do_update'
  get '/users/update' => 'users#update'
  post '/users/update' => 'users#update'

  match '/ec2nodes/notify/:cmd/:ec2_instance_id', :controller => "ec2nodes", :action => "notify", :via => [:get, :post]
  post '/ec2nodes/do_terminate_instances_for_user/:id?ec2_instance_id=:ec2_instance_id' => 'ec2nodes#do_terminate_instances_for_user'
  post '/ec2nodes/do_stop_instances_for_user/:id?ec2_instance_id=:ec2_instance_id' => 'ec2nodes#do_stop_instances_for_user'
  post '/ec2nodes/reparent_node/:id?ec2_instance_id=:node_id' => 'ec2nodes#reparent_node'
  post '/nodes/refresh/:id' => 'nodes#refresh'
  get '/ec2nodes' => 'ec2nodes#get_users'
  get '/server_nodes/index/:id' => 'server_nodes#get_status_for_server'
  get '/server_nodes/get_status_for_server/:id' => 'server_nodes#get_status_for_server'

  get '/logs/show/:id' => 'logs#show'
  post '/logs/show/:id' => 'logs#show'
        
  get '/ec2nodes/get_status_for_user/:id' => 'ec2nodes#get_status_for_user'
  post '/ec2nodes/get_status_for_user/:id' => 'ec2nodes#get_status_for_user'
  get '/ec2nodes/launch_instances_for_user/:id' => 'ec2nodes#launch_instances_for_user'
  post '/ec2nodes/launch_instances_for_user/:id' => 'ec2nodes#launch_instances_for_user'
  get '/ec2nodes/get_amis' => 'ec2nodes#get_amis'
  post '/ec2nodes/get_amis' => 'ec2nodes#get_amis'
  get '/ec2nodes/get_users' => 'ec2nodes#get_users'
  get '/ec2nodes/get_registered_amis' => 'ec2nodes#get_registered_amis'
  post '/ec2nodes/do_launch_instances_for_user/:id' => 'ec2nodes#do_launch_instances_for_user'

  resources :delayed_jobs, :ec2_nodes, :users, :node_types, :instance_types, :server_nodes, :logs

  # You can have the root of your site routed with "root"
  # just remember to delete public/index.html.
  # root :to => 'welcome#index'

  root :to => "pipelines#index"
  
  # See how all your routes lay out with "rake routes"

  # This is a legacy wild controller route that's not recommended for RESTful applications.
  # Note: This route will make all actions in every controller accessible via GET requests.
  match ':controller/:action/:id', via: [ :get, :post]
  match ':controller/:action/:id.:format', via: [ :get, :post]
  match ':controller/:action', via: [ :get, :post]
  match ':controller/:action.:format', via: [ :get, :post]
  match ':controller/:id/:action', via: [ :get, :post]
  match ':controller/:id/:action.:format', via: [ :get, :post]
end
