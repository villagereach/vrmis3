  map.mini_table '/:path/render_mini_table', :action => 'render_mini_table', :controller => :olmis

  map.resources :users, :member => { :profile => [:get, :put] }

  map.new_fridge_status '/fridge_statuses/new', :controller => :fridge_statuses, :action => 'create', :conditions => { :method => :post }
  
  map.resources :fridges, :path_prefix => 'cold_chain'
  map.resources :health_centers, :has_many => [:fridges, :street_addresses]

  map.health_center_cold_chain '/cold_chain/:health_center', :controller => 'cold_chain', :action => 'location'
  map.cold_chain '/cold_chain', :controller => 'cold_chain', :action => 'index'

  map.fc_visits          '/fcs',                  :controller => 'field_coordinators', :action => 'index', :conditions => { :method => :get }
  map.fc_visits_by_month '/fcs/:visit_month',     :controller => 'field_coordinators', :action => 'index', :conditions => { :method => :get }
  map.fc                 '/fcs/:id/:visit_month', :controller => 'field_coordinators', :action => 'show',  :conditions => { :method => :get }

  map.isa '/pickups/:delivery_zone/isa/:health_center', :controller => 'pickups', :action => 'isa_edit'
  map.isa_redirect '/pickups/:delivery_zone/isa_redirect', :controller=>'pickups', :action => 'isa_redirect'

  map.pickup_request '/pickups/:delivery_zone/request.:format', :controller => 'pickups', :action => 'pickup_request', :conditions => { :method => :get }

  map.pickup_new '/pickups/:delivery_zone/new.:format', :controller => 'pickups', :action => 'pickup_new'
  map.pickup_edit '/pickups/:delivery_zone/:date/edit', :controller => 'pickups', :action => 'pickup_edit'
  map.pickup '/pickups/:delivery_zone/:date', :controller => 'pickups', :action => 'pickup'
  map.pickups '/pickups/:delivery_zone', :controller => 'pickups', :action => 'pickups'

  map.unload_new '/unloads/:delivery_zone/new', :controller => 'pickups', :action => 'unload_new'
  map.unload_edit '/unloads/:delivery_zone/:date/edit', :controller => 'pickups', :action => 'unload_edit'
  map.unload '/unloads/:delivery_zone/:date', :controller => 'pickups', :action => 'unload'
  map.unloads '/unloads/:delivery_zone', :controller => 'pickups', :action => 'unloads'
  
  map.connect '/set_date_period', :controller=>'dashboard', :action=>'set_date_period'
  map.login   '/login',  :controller => 'login', :action => 'login'
  map.logout  '/logout', :controller => 'login', :action => 'logout'
  map.is_logged_in '/logged-in', :controller => 'olmis', :action => 'logged_in'
  
  map.connect '/graph_data/:graph.:format', :controller => 'graph_data', :action => 'graph'
 
  map.connect '/config',  :controller => 'dashboard', :action => 'config'

  map.xforms_list  '/formList',             :controller => 'data_sources', :action => 'list_xforms',  :conditions => { :method => :get }
  map.xform_submit '/submission',           :controller => 'data_sources', :action => 'submit_xform', :conditions => { :method => :post }

  map.manifest     '/xforms/manifest.:format', :controller => 'data_sources', :action => 'manifest',  :conditions => { :method => :get }
  map.xform_index  '/xforms',               :controller => 'data_sources', :action => 'index',        :conditions => { :method => :get }
  map.xform        '/xforms/:name.:format', :controller => 'data_sources', :action => 'get_xform',    :conditions => { :method => :get }
  map.data_sources        '/upload',        :controller => 'data_sources', :action => 'index',        :conditions => { :method => :get }
  map.data_sources_import '/upload',        :controller => 'data_sources', :action => 'submit_xform', :conditions => { :method => :post }

  map.offline_visit '/offline/:name', :controller => 'data_sources', :action => 'get_offline', :conditions => { :method => :get }

  map.javascript '/javascripts/:action.js', :controller => 'javascripts', :format => 'js'

  map.visits                  '/visits', :controller => 'visits', :action => 'index', :conditions => { :method => :get }
  map.visits_search           '/visits/search', :controller => 'visits', :action => 'search', :conditions => { :method => :get }
  map.visits_by_month         '/visits/:visit_month', :controller => 'visits', :action => 'by_month', :conditions => { :method => :get }
  map.health_center_visit_title '/visits/:visit_month/:health_center/title', :controller => 'visits', :action => 'health_center_monthly_visit_title'

  map.health_center_visit     '/visits/:visit_month/:health_center.:format', :screen => 'visit', :controller => 'visits', :action => 'health_center_monthly_visit'

  map.nuke_caches             '/nuke_caches', :controller => 'olmis', :action => 'nuke_caches'

  map.health_center_equipment_status   '/visits/:visit_month/:health_center/equipment_status', 
    :screen => 'equipment_status', :controller => 'visits', :action => 'health_center_equipment'
  
  map.health_center_cold_chain '/visits/:visit_month/:health_center/cold_chain', 
    :screen => 'cold_chain', :controller => 'visits', :action => 'health_center_cold_chain'
    
  map.health_center_stockcards '/visits/:visit_month/:health_center/stockcards', 
    :screen => 'stock_cards', :controller => 'visits', :action => 'health_center_stock_cards'

  map.health_center_inventory '/visits/:visit_month/:health_center/inv/:screen', :controller => 'visits', :action => 'health_center_inventory'
  
  tables = Olmis.additional_visit_klasses
  if tables.present?
    tables.each do |table|
      map.send("health_center_#{table.xforms_group_name}", "/visits/:visit_month/:health_center/#{table.visit_navigation_category}/:screen", 
        { :controller => 'visits', :action => table.xforms_group_name })
    end
  end
  map.health_center_tally     '/visits/:visit_month/:health_center/:screen',               :controller => 'visits', :action => 'health_center_tally'
  map.health_center_tally_fmt '/visits/:visit_month/:health_center/:screen.:type.:format', :controller => 'visits', :action => 'health_center_tally'

  map.root :controller => 'dashboard', :action => 'homepage'

  map.reports '/reports', :controller => 'reports', :action => 'index'
  map.report_maps '/reports/:action', :controller => 'reports'

  map.delivery_zone_selector '/dz', :controller => 'olmis', :action => 'delivery_zone_selector'
  map.district_selector      '/dct', :controller => 'olmis', :action => 'district_selector'
