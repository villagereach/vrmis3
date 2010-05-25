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
    @visits = WarehouseVisit.find_all_by_warehouse_id(@zone.warehouse, :order => 'visit_month DESC', :limit => 6)
  end
  
  def pickup_request
    setup_inventory('DeliveryRequest')
    @amounts = @zone.total_ideal_stock_by_package
    render :inventory_delivery_request
  end

  def pickup_new
    setup_visit
    @zone.total_ideal_stock_by_package.each{|package,requested| @amounts[package] = { 'DeliveryRequest' => requested, 'DeliveryPickup' => nil } }
  end

  def pickup_create
    setup_visit
    handle_submit(pickups_url)
    render :action => 'pickup_new' unless performed?
  end

  def pickup_edit
    setup_visit
    picked_up_inventory_counts = Hash[*@visit.pickup.package_counts.map{|pc| [ pc.package, pc.quantity ] }.flatten]
    requested_inventory_counts = Hash[*@visit.request.package_counts.map{|pc| [ pc.package, pc.quantity ] }.flatten]

    requested_inventory_counts.keys.each do |package|
      @amounts[package] = {
        'DeliveryRequest' => requested_inventory_counts[package],
        'DeliveryPickup'  => picked_up_inventory_counts[package]
      }
    end
  end

  def pickup_update
    setup_visit
    handle_submit(pickups_url)
    render :action => 'pickup_edit' unless performed?
  end

  # def unloads
  #   @zone = DeliveryZone.find_by_code(params[:delivery_zone])
  #   @unloads = Inventory.find_all_by_inventory_type_and_stock_room_id('DeliveryReturn', @zone.warehouse.stock_room, :order => 'date desc', :limit=>6)
  # end

  # def unload
  #   setup_inventory('DeliveryReturn')
  #   @show_date = true
  #   @verb_code = 'show'
  #   @back_link = helpers.link_to(I18n.t('inventory.back_to_returns'),unloads_path) 
  #   if @inventory.nil?
  #     redirect_to :action=>'unload_new', :date=>params[:date], :delivery_zone=>params[:delivery_zone]
  #   else
  #     @amounts = @inventory.package_count_quantity_by_package
  #     render :inventory_table
  #   end
  # end

  # def unload_edit
  #   setup_inventory('DeliveryReturn')
  #   @show_date = true
  #   @verb = 'edit'
  #   if @inventory.nil?
  #     redirect_to :action=>'unload_new', :date=>params[:date], :delivery_zone=>params[:delivery_zone]
  #   else
  #     if params[:inventory]
  #       @amounts = amounts_from_params
  #     else
  #       @amounts = {}
  #       Inventory.find_by_inventory_type_and_stock_room_id_and_date('DeliveryPickup', @zone.warehouse.stock_room, @date).each{|p,v| @amounts[p] = { 'DeliveryPickup' => v, 'DeliveryReturn' => nil } }
  #     end
  #     save_if_post_and_redirect_or_render_form('DeliveryReturn', :unload)
  #   end
  # end

  # def unload_new
  #   setup_inventory('DeliveryReturn')
  #   @show_date = true
  #   @edit_date = true
  #   @verb_code = 'new'
  #   if params[:inventory] 
  #     @amounts = amounts_from_params 
  #   else
  #     @amounts = {}
  #     Inventory.find_by_inventory_type_and_stock_room_id_and_date('DeliveryPickup', @zone.warehouse.stock_room, @date).each{|p,v| @amounts[p] = { 'DeliveryPickup' => v, 'DeliveryReturn' => nil } }
  #   end
  #   save_if_post_and_redirect_or_render_form('DeliveryReturn', :unload)
  # end

  # def isa_redirect
  #   logger.info " isad1"
  #   redirect_to isa_path(params[:delivery_zone],params[:hc])
  #   logger.info " isad2"
  # end
  
  # def isa_edit
  #   @zone = DeliveryZone.find_by_code(params[:delivery_zone])
  #   @hc = HealthCenter.find_by_code(params[:health_center])
  #   @sr = @hc.stock_room
  #   @amounts = @sr.package_counts_by_package

  #   @show_date = false
  #   @page_title = I18n.t('inventory.IdealStockAmount.edit', :where => @hc.name)

  #   @errors = {}
  #   if request.post?
  #     begin
  #       IdealStockAmount.transaction do
  #         params[:inventory][:packages].each do |code, amount|
  #           package = Package.find_by_code(code)
  #           i = IdealStockAmount.find_or_create_by_package_id_and_stock_room_id(package, @sr)
  #           i.quantity = amount
  #           if i.valid?
  #             i.save
  #           else 
  #             @errors[code] = i.errors
  #           end
  #         end
  #         redirect_to pickups_path and return if @errors.empty?
  #       end
  #     rescue ActiveRecord::ActiveRecordError        
  #     end
  #   end
  #   render :inventory_form
  # end

  def warehouse_monthly_visit
    setup_visit
    handle_submit
  end

  private

  def handle_submit(redirect_target = {})
    if params[:format] == 'xml'
      # TODO: Setup for XML submission
    elsif params[:format] == 'json'
      submission = DataSubmission.create(
        :user => @current_user, 
        :data_source => DataSource['JsonPickupDataSource'],
        :remote_ip => request.remote_ip,
        :content_type => request.headers['CONTENT_TYPE'].to_s,
        :data => request.raw_post)
    else
      submission = DataSubmission.create(
        :user => @current_user,
        :data_source => DataSource['WebPickupDataSource'],
        :remote_ip => request.remote_ip,
        :content_type => request.headers['CONTENT_TYPE'].to_s,
        :data => request.raw_post)
    end

    visit_month = params[:warehouse_visit].maybe[:visit_month] || @date.to_date_period

    WarehouseVisit.transaction do
      @visit, @errors = submission.process_pickup(@visit, @current_user)
    end

    if @errors.none? { |slice, slice_errors| slice_errors.present? }
      submission.status = 'success'
      submission.save

      if %w(xml json).include?(params[:format])
        render :text => 'ok'
      else
        redirect_to redirect_target
      end
    else
      submission.status = 'error'
      submission.save

      render :text => 'error', :status => 400 and return if %w(xml json).include?(params[:format])
    end
  end

  def setup_visit
    @zone = DeliveryZone.find_by_code(params[:delivery_zone])
    @visit = WarehouseVisit.find_or_initialize_by_warehouse_id_and_visit_month(@zone.warehouse.id, params[:visit_month] || Date.today.to_date_period)

    # The date may come in as either a Date or a String
    date_param = params[:date] || params[:inventory].maybe[:date] || Date.today
    @date = @visit.date || (date_param.is_a?(Date) ? date_param : Date.parse(date_param))

    @amounts = {}
    @errors = {}
  end

  def setup_inventory(type)
    @zone = DeliveryZone.find_by_code(params[:delivery_zone])

    # The date may come in as either a Date or a String
    date_param = params[:date] || params[:inventory].maybe[:date] || Date.today
    @date = date_param.is_a?(Date) ? date_param : Date.parse(date_param)

    @inventory = Inventory.find_by_inventory_type_and_stock_room_id_and_date(type, @zone.warehouse.stock_room, @date)
    page_title_key = "inventory.#{type}.#{@verb_code || 'show'}"
    @page_title = I18n.t(page_title_key, :where => @zone.name)
    @amounts = {}
    @errors = {}
  end

  # def amounts_from_params
  #   types = params[:inventory].keys.select{|k| k =~ /^Delivery/}
  #   Hash[*Package.active.map{ |p| [ p, types.inject({}) do |hash,key|
  #                                                         hash[key] = params[:inventory][key][p.code]
  #                                                         hash
  #                                                       end ] }.flatten]
  # end

  # def save_inventory(type)
  #   begin
  #     inventories = { type => nil }
  #     inventories['DeliveryRequest'] = nil if type == 'DeliveryPickup'
  #     Inventory.transaction do
  #       inventories.keys.each do |t|
  #         inventory = inventories[t] = Inventory.find_or_initialize_by_stock_room_id_and_date_and_inventory_type(@zone.warehouse.stock_room_id, params[:inventory][:date], t)
  #         inventory.user = @current_user
  #         inventory.save!
  #         amounts_from_params.each do |package, amounts|
  #           pc = PackageCount.find_by_inventory_id_and_package_id(inventory.id, package.id)
  #           pc ||= PackageCount.new(:inventory => inventory, :package => package)
  #           pc.quantity = amounts[t].to_i
  #           if pc.valid?
  #             pc.save
  #           else
  #             @errors[t] ||= {}
  #             @errors[t][package.code] = pc.errors
  #           end
  #           pc.save!
  #         end
  #       end
  #       raise "Invalid record(s)" if @errors.any?{|slice, errors| errors.present?}  # abort the transaction
  #     end
  #     return inventories
  #   rescue ActiveRecord::RecordInvalid => e
  #     @errors['common'] = e.to_s
  #     return nil
  #   end
  # end    

  # def save_if_post_and_redirect_or_render_form(type, success_action)
  #   if request.post?  && inventories = save_inventory(type)
  #     redirect_to :action => success_action, :params => { :date => inventories.values.first.date.strftime('%Y-%m-%d'), :delivery_zone => @zone.code }
  #   else
  #     begin
  #       render "inventory_#{type.underscore}_form"
  #     rescue ActionView::MissingTemplate
  #       render :inventory_form
  #     end
  #   end
  # end
  
end
