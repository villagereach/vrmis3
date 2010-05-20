class PickupsController < OlmisController
  # add_breadcrumb(lambda { |c| I18n.t('breadcrumb.pickups', :name => c.delivery_zone.name) }, 'pickups_path', 
  #                :only => ['pickups', 'pickup', 'pickup_new', 'pickup_edit', 'isa', 'isa_edit'])
  # add_breadcrumb(lambda { |c| I18n.l(Date.parse(c.param_date), :format => :default) }, 'pickup_path',
  #                :only => ['pickup','pickup_edit'])
  # add_breadcrumb(lambda { |c| I18n.t('breadcrumb.new_pickup', :name => c.delivery_zone.name) }, '',
  #                :only => ['pickup_new', 'pickup_request'])

  # add_breadcrumb(lambda { |c| I18n.t('breadcrumb.unloads', :name => c.delivery_zone.name) }, 'unloads_path', 
  #                :only => ['unloads', 'unload', 'unload_new', 'unload_edit' ])
  # add_breadcrumb(lambda { |c| I18n.l(Date.parse(c.param_date), :format => :default) }, 'unload_path',
  #                :only => ['unload','unload_edit'])
  # add_breadcrumb(lambda { |c| I18n.t('breadcrumb.new_unload', :name => c.delivery_zone.name) }, '',
  #                :only => 'unload_new')

  # add_breadcrumb('breadcrumb.edit', '',
  #                :only => ['pickup_edit','unload_edit'])

  # add_breadcrumb(lambda { |c| I18n.t('breadcrumb.edit_ideal_stock', :name => c.health_center.name) }, '',
  #                :only => 'isa_edit')


  def pickups
    @zone = DeliveryZone.find_by_code(params[:delivery_zone])
    @pickups = Inventory.find_all_by_inventory_type_and_stock_room_id('DeliveryPickup', @zone.warehouse.stock_room, :order => 'date desc', :limit=>6)
  end
  
  def unloads
    @zone = DeliveryZone.find_by_code(params[:delivery_zone])
    @unloads = Inventory.find_all_by_inventory_type_and_stock_room_id('DeliveryReturn', @zone.warehouse.stock_room, :order => 'date desc', :limit=>6)
  end

  def pickup_request
    setup_inventory('DeliveryRequest')
    @amounts = @zone.total_ideal_stock_by_package
    render :inventory_delivery_request
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
      @amounts = @inventory.package_count_quantity_by_package
      render :inventory_table
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
      @amounts = @inventory.package_count_quantity_by_package
      render :inventory_table
    end
  end

  def pickup_edit
    setup_inventory('DeliveryPickup')
    @show_date = true
    @verb = 'edit'
    if @inventory.nil?
      redirect_to :action=>'pickup_new', :date=>params[:date], :delivery_zone=>params[:delivery_zone]
    else
      if params[:inventory]
        @amounts = amounts_from_params
      else
        @amounts = {}
        @zone.total_ideal_stock_by_package.each{|package,requested| @amounts[package] = { 'DeliveryRequest' => requested, 'DeliveryPickup' => nil } }
      end
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
      if params[:inventory]
        @amounts = amounts_from_params
      else
        @amounts = {}
        Inventory.find_by_inventory_type_and_stock_room_id_and_date('DeliveryPickup', @zone.warehouse.stock_room, @date).each{|p,v| @amounts[p] = { 'DeliveryPickup' => v, 'DeliveryReturn' => nil } }
      end
      save_if_post_and_redirect_or_render_form('DeliveryReturn', :unload)
    end
  end

  def pickup_new
    setup_inventory('DeliveryPickup')
    @zone.total_ideal_stock_by_package.each{|package,requested| @amounts[package] = { 'DeliveryRequest' => requested, 'DeliveryPickup' => nil } }
    render :inventory_delivery_pickup_form
  end

  def unload_new
    setup_inventory('DeliveryReturn')
    @show_date = true
    @edit_date = true
    @verb_code = 'new'
    if params[:inventory] 
      @amounts = amounts_from_params 
    else
      @amounts = {}
      Inventory.find_by_inventory_type_and_stock_room_id_and_date('DeliveryPickup', @zone.warehouse.stock_room, @date).each{|p,v| @amounts[p] = { 'DeliveryPickup' => v, 'DeliveryReturn' => nil } }
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
    render :inventory_form
  end

  def warehouse_monthly_visit
    if params[:format] == 'xml'
      # TODO: Setup for XML submission
    elsif params[:format] == 'json'
      # TODO: Setup for JSON submission
    else
      # TODO: Setup for HTML submission
    end

    # TODO: Process the data

    # FIXME: Until the data is actually processed, return an error
    render :text => 'error', :status => 400 and return #if %w(xml json).include?(params[:format])
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
    types = params[:inventory].keys.select{|k| k =~ /^Delivery/}
    Hash[*Package.active.map{ |p| [ p, types.inject({}) do |hash,key|
                                                          hash[key] = params[:inventory][key][p.code]
                                                          hash
                                                        end ] }.flatten]
  end


  def save_inventory(type)
    begin
      inventories = { type => nil }
      inventories['DeliveryRequest'] = nil if type == 'DeliveryPickup'
      Inventory.transaction do
        inventories.keys.each do |t|
          inventory = inventories[t] = Inventory.find_or_initialize_by_stock_room_id_and_date_and_inventory_type(@zone.warehouse.stock_room_id, params[:inventory][:date], t)
          inventory.user = @current_user
          inventory.save!
          amounts_from_params.each do |package, amounts|
            pc = PackageCount.find_by_inventory_id_and_package_id(inventory.id, package.id)
            pc ||= PackageCount.new(:inventory => inventory,:package=>package)
            pc.quantity = amounts[inventory].to_i
            if pc.valid?
              pc.save
            else
              @errors[t] ||= {}
              @errors[t][package.code] = pc.errors
            end
            pc.save!
          end
        end
        raise "Invalid record(s)" if @errors.any?{|slice, errors| errors.present?}  # abort the transaction
      end
      return inventories
    rescue ActiveRecord::RecordInvalid => e
      @errors['common'] = e.to_s
      return nil
    end
  end    

  def save_if_post_and_redirect_or_render_form(type, success_action)
    if request.post?  && inventories = save_inventory(type)
      redirect_to :action => success_action, :params => { :date => inventories.values.first.date.strftime('%Y-%m-%d'), :delivery_zone => @zone.code }
    else
      begin
        render "inventory_#{type.underscore}_form"
      rescue ActionView::MissingTemplate
        render :inventory_form
      end
    end
  end
  
end
