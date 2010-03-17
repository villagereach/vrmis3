class PickupsController < OlmisController

  add_breadcrumb(lambda { |c| I18n.t('breadcrumb.pickups', :name => c.delivery_zone.name) }, 'pickups_path', 
                 :only => ['pickups', 'pickup', 'pickup_new', 'pickup_edit', 'isa', 'isa_edit'])
  add_breadcrumb(lambda { |c| I18n.l(Date.parse(c.param_date), :format => :default) }, 'pickup_path',
                 :only => ['pickup','pickup_edit'])
  add_breadcrumb(lambda { |c| I18n.t('breadcrumb.new_pickup', :name => c.delivery_zone.name) }, '',
                 :only => 'pickup_new')

  add_breadcrumb(lambda { |c| I18n.t('breadcrumb.unloads', :name => c.delivery_zone.name) }, 'unloads_path', 
                 :only => ['unloads', 'unload', 'unload_new', 'unload_edit' ])
  add_breadcrumb(lambda { |c| I18n.l(Date.parse(c.param_date), :format => :default) }, 'unload_path',
                 :only => ['unload','unload_edit'])
  add_breadcrumb(lambda { |c| I18n.t('breadcrumb.new_unload', :name => c.delivery_zone.name) }, '',
                 :only => 'unload_new')

  add_breadcrumb('breadcrumb.edit', '',
                 :only => ['pickup_edit','unload_edit'])

  add_breadcrumb(lambda { |c| I18n.t('breadcrumb.edit_ideal_stock', :name => c.health_center.name) }, '',
                 :only => 'isa_edit')


  def pickups
    @zone = DeliveryZone.find_by_code(params[:delivery_zone])
    @pickups = Inventory.find_all_by_inventory_type_and_stock_room_id('DeliveryPickup', @zone.warehouse.stock_room, :order => 'date desc', :limit=>6)
  end
  
  def unloads
    @zone = DeliveryZone.find_by_code(params[:delivery_zone])
    @unloads = Inventory.find_all_by_inventory_type_and_stock_room_id('DeliveryReturn', @zone.warehouse.stock_room, :order => 'date desc', :limit=>6)
  end

  def pickup
    setup_inventory('DeliveryPickup')
    @show_date = true
    @verb_code = 'show'
    @back_link = helpers.link_to(I18n.t('inventory.back_to_pickups'),pickups_path) 
    if @inventory.nil?
      redirect_to :action=>'pickup_new', :date => params[:date], :delivery_zone=>params[:delivery_zone]
    else
      #blank column for warehouse print form
      @comparison_column = I18n.t('inventory.amount_picked_up')
      @comparisons = {}
      @comparison_class = "pickup_box not_on_screen"
      @amounts = @inventory.package_counts_by_package(true)
      render :template=>'pickups/inventory_table'
    end
  end
  
  def unload
    setup_inventory('DeliveryReturn')
    @show_date = true
    @verb_code = 'show'
    @back_link = helpers.link_to(I18n.t('inventory.back_to_returns'),unloads_path) 
    if @inventory.nil?
      redirect_to :action=>'unload_new', :date=>params[:date], :delivery_zone=>params[:delivery_zone]
    else
      @amounts = @inventory.package_counts_by_package(true)
      render :template=>'pickups/inventory_table'
    end
  end

  def pickup_edit
    setup_inventory('DeliveryPickup')
    @show_date = true
    @verb = 'edit'
    if @inventory.nil?
      redirect_to :action=>'pickup_new', :date=>params[:date], :delivery_zone=>params[:delivery_zone]
    else
      @amounts = params[:inventory] ? amounts_from_params : @inventory.package_counts_by_package(true)
      save_if_post_and_redirect_or_render_form('DeliveryPickup', :pickup)
    end
  end

  def unload_edit
    setup_inventory('DeliveryReturn')
    @show_date = true
    @verb = 'edit'
    if @inventory.nil?
      redirect_to :action=>'unload_new', :date=>params[:date], :delivery_zone=>params[:delivery_zone]
    else
      @amounts = params[:inventory] ? amounts_from_params : @inventory.package_counts_by_package(true)
      save_if_post_and_redirect_or_render_form('DeliveryReturn', :unload)
    end
  end

  def pickup_new
    setup_inventory('DeliveryPickup')
    @show_date = true
    @edit_date = true
    @verb_code = 'new'
    @amounts = params[:inventory] ? amounts_from_params : @zone.total_ideal_stock_by_package
    save_if_post_and_redirect_or_render_form('DeliveryPickup', :pickup)
  end

  def unload_new
    setup_inventory('DeliveryReturn')
    @show_date = true
    @edit_date = true
    @verb_code = 'new'
    if params[:inventory] 
      @amounts = amounts_from_params 
    else
      #default amounts are zero.  
      Package.all.each{|p| @amounts[p] = 0}
    end
    save_if_post_and_redirect_or_render_form('DeliveryReturn', :unload)
  end

  def isa_redirect
    logger.info " isad1"
    redirect_to isa_path(params[:delivery_zone],params[:hc])
    logger.info " isad2"
  end
  
  def isa_edit
    @zone = DeliveryZone.find_by_code(params[:delivery_zone])
    @hc = HealthCenter.find_by_code(params[:health_center])
    @sr = @hc.stock_room
    @amounts = @sr.package_counts_by_package

    @show_date = false
    @page_title = I18n.t('inventory.IdealStockAmount.edit', :where => @hc.name)

    @errors = {}
    if request.post?
      begin
        IdealStockAmount.transaction do
          params[:inventory][:packages].each do |code, amount|
            package = Package.find_by_code(code)
            i = IdealStockAmount.find_or_create_by_package_id_and_stock_room_id(package, @sr)
            i.quantity = amount
            if i.valid?
              i.save
            else 
              @errors[code] = i.errors
            end
          end
          redirect_to pickups_path and return if @errors.empty?
        end
      rescue ActiveRecord::ActiveRecordError        
      end
    end
    render :template => 'pickups/inventory_form'
  end


  private


  def setup_inventory(type)    
    @zone = DeliveryZone.find_by_code(params[:delivery_zone])
    @date = Date.parse(params[:date] || params[:inventory].maybe[:date] || Date.today.to_s)
    @inventory = Inventory.find_by_inventory_type_and_stock_room_id_and_date(type, @zone.warehouse.stock_room, @date)
    page_title_key = "inventory.#{type}.#{@verb_code || 'show'}"
    @page_title = I18n.t(page_title_key, :where => @zone.name)
    @amounts = {}
    @errors = {}
  end
  
  def amounts_from_params
    amounts = Hash[*Package.all.map{ |p| [p, params[:inventory][:packages][p.code]] }.flatten]
  end


  def save_inventory(type)
    begin
      inventory = Inventory.find_or_initialize_by_stock_room_id_and_date_and_inventory_type(@zone.warehouse.stock_room_id, params[:inventory][:date], type)
      Inventory.transaction do
        inventory.user = @current_user
        inventory.save!
        amounts_from_params.each do |package, amount|
          pc = PackageCount.find_by_inventory_id_and_package_id(inventory.id, package.id)
          pc ||= PackageCount.new(:inventory => inventory,:package=>package)
          pc.quantity = amount.to_i
          pc.save!
        end
      end
      return inventory
    rescue ActiveRecord::RecordInvalid
      flash[:notice] = "Invalid entry: #{inventory.errors.full_messages}"
      return nil
    end
  end    

  def save_if_post_and_redirect_or_render_form(type, success_action)
    if request.post?  && inventory = save_inventory(type)
      redirect_to :action => success_action, :params => { :date => inventory.date.strftime('%Y-%m-%d'), :delivery_zone => @zone.code }
    else
      render :template=>'pickups/inventory_form'
    end
  end
  
end
