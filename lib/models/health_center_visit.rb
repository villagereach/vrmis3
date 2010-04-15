# == Schema Information
# Schema version: 20100127014005
#
# Table name: health_center_visits
#
#  id               :integer(4)      not null, primary key
#  user_id          :integer(4)      not null
#  health_center_id :integer(4)      not null
#  visit_month      :string(255)     not null
#  visited_at       :date            not null
#  vehicle_code     :string(255)     default(""), not null
#  visit_status     :string(255)     default("Visited"), not null
#  notes            :text            default(""), not null
#  data_status      :string(255)     default("pending"), not null
#  epi_data_ready   :boolean(1)      default(TRUE), not null
#  created_at       :datetime
#  updated_at       :datetime
#

class HealthCenterVisit < ActiveRecord::Base
  belongs_to :field_coordinator, :foreign_key => 'user_id', :class_name => 'User'
  belongs_to :health_center

  has_many :equipment_counts
  has_many :equipment_statuses
  has_many :stock_card_statuses
  
  has_many :health_center_visit_inventory_groups
  
  has_and_belongs_to_many :data_submissions, :order => 'created_at desc'
  
  validates_presence_of :user_id
  validates_presence_of :health_center_id
  validates_presence_of :visit_month
  validates_presence_of :visited_at
  #validates_presence_of :vehicle_code, :allow_blank => true
  validates_presence_of :visit_status
  validates_presence_of :data_status

  defaults :visit_status => 'Visited', :data_status => 'pending', :vehicle_code => lambda { |r| r.field_coordinator.try(&:default_vehicle_code) }

  named_scope :recent, lambda{|count| { :order => 'updated_at DESC', :limit => count } }

  named_scope :by_user, lambda{|user| { :conditions => { :user_id => user } } }

  ExcusableNonVisitReasons = ['health_center_closed'] 
  
  def date_period
    visit_month
  end
  
  def validate
    if visit_status_changed?
      if @visited_status.blank? && @unvisited_status.blank?
        errors.add(:visited, 'set_visited')
      elsif !@visited_status.blank? && !@unvisited_status.blank?
        errors.add(:visited, 'visited_conflict')
      end
    end
    
    if visit_status == 'other' && notes.blank?
      errors.add(:notes, 'describe_reason_for_not_visiting')
    end
    
    super
  end
  
  def event_log
    []
  end
  
  def self.tally_hash
    @tally_hash ||= Hash[*Olmis.configuration['tallies'].map { |k, v| [k, k] }.flatten]
  end
  
  def self.inventory_screen_hash
    @inventory_hash ||= Inventory.inventory_screens.inject({}) { |hash, screen| hash[screen] = screen.camelize ; hash }
  end
  
  def self.tasks_and_tables
    tally_hash.merge(inventory_screen_hash).merge({
      "visit"       => "Visit",
      "general"     => "GeneralEquipment",
      "cold_chain"  => "ColdChainEquipment",
      "stock_cards" => "StockCardEquipment"
    })
  end
  
  def availability_class(task)
    if new_record?
      "preavailable"
    elsif !epi_data_ready && self.class.tally_hash.has_key?(task)
      "unavailable"
    elsif !visited && [:inventory, :delivery, :general, :cold_chain, :stock_cards].include?(task)
      "unavailable"
    else
      "available"
    end
  end
  
  def visited
    visit_status == 'Visited'
  end
  
  def hour
    "12:00" #visited_at.strftime("%H:00")
  end
  
  def hour=(h)
    #self.visited_at = self.visited_at.to_date.to_time + h.to_i.hours
  end
  
  def date
    visited_at
  end

  def date=(d)
    self.visited_at = d if d #+ (visited_at ? visited_at.hour.hours : 0.hours) if d
  end
  
  def visited?
    visited
  end
  
  def visited=(v)
    v = (v.to_s != 'false')
    if v
      @visited_status = 'visited'
      self.visit_status = 'Visited'
    else
      @visited_status = ''
      self.visit_status = '' if @unvisited_status.blank?
    end
  end
  
  def reason_for_not_visiting=(r)
    if r.blank?
      @unvisited_status = ''
      self.visit_status = 'Visited'
    else
      self.visit_status = @unvisited_status = r
    end
  end
  
  def reason_for_not_visiting
    if visited then '' else visit_status end
  end
  
  def self.visited_options
    [[I18n.t('HealthCenterVisit.visited_yes'), true], [I18n.t('HealthCenterVisit.visited_no'), false]]
  end                   
  
  def self.unvisited_options
    ['road_problem', 'vehicle_problem', 'health_center_closed', 'other'].map { |c| [ I18n.t("HealthCenterVisit.#{c}"), c ] }
  end
  
  # Please do not ever refer to these by number.
  Statuses = [:REPORT_COMPLETE, :REPORT_INCOMPLETE, :REPORT_NOT_DONE, :REPORT_NOT_VISITED, :REPORT_IRRELEVANT]
  REPORT_COMPLETE =    :REPORT_COMPLETE
  REPORT_INCOMPLETE =  :REPORT_INCOMPLETE
  REPORT_NOT_DONE =    :REPORT_NOT_DONE
  REPORT_NOT_VISITED = :REPORT_NOT_VISITED
  REPORT_IRRELEVANT =  :REPORT_IRRELEVANT
  
  # Return a hash of values consisting of the status for each visit batch element
  #   (existing inventory, delivered inventory, general equipment, cold chain equipment, stock card equipment,
  #   EPI usage, Adult vaccinations, Child vaccinations, Full vaccinations, and RDTs reports).

  def status_by_table_with_visit
    reports_status = status_by_table
    reports_status['Visit'] = new_record? ? REPORT_NOT_DONE : REPORT_COMPLETE
    reports_status
  end
  
  def progress_numbers(return_parts=true)
    required = status_by_table_with_visit.reject{ |k,v| [REPORT_NOT_VISITED, REPORT_IRRELEVANT].include?(v) }.size
    done = status_by_table_with_visit.reject{ |k,v| v != REPORT_COMPLETE }.size
    percent = (done * 100) / required
    return_parts ? [done, required, percent] : percent
  end

  def progress_percent
    progress_numbers(false)
  end

  
  # * <tt>:group => true</tt> - Return a hash of values consisting of the status for each visit batch group
  #   (inventory, equipment, and EPI reports).
  def status_by_table_group(status = reports_status)
    {
      'Inventory' => status['HealthCenterInventory'],
      'Equipment' => combined_status(status['GeneralEquipment'],
                                     status['ColdChainEquipment'],
                                     status['StockCardEquipment']),
      'EPI'       => combined_status(*status.values_at(self.class.tally_hash.keys))
    }
  end

  def count_inventory(screen)
    do_inventory = true  # NOTE: All HCs require inventory now, but may not in the future
    expected, actual = entry_counts[screen] ||= begin
      packages = Package.all.select { |p| Inventory.directly_collected_types.any? { |t| p.inventoried_by_type?(t, screen) } }
      types = Inventory.directly_collected_types.select { |t| packages.any? { |p| p.inventoried_by_type?(t, screen) } }
      if inventories = Inventory.all(:conditions => { :stock_room_id => health_center.stock_room, :inventory_type => types, :date => date })
        package_codes = packages.map(&:code)
        package_counts = inventories.map{|inventory| inventory.package_counts_by_package_code.delete_if{|k,v| !package_codes.include?(k)}.values}.flatten
        entries = package_counts.reject{|pc| pc.id.nil?}.size
        expected_entries = package_counts.size
      end
      [entries || 0, expected_entries || (do_inventory ? 1 : 0)]
    end
  end

  def inventory_status(screen)
    if date
      reporting_status_field(*count_inventory(screen))
    end
  end
  
  def equipment_status
    if date
      expected, statuses, counts = entry_counts['equipment'] ||= [
        EquipmentType.count, equipment_statuses.count, equipment_counts.count 
      ] 
      reporting_status_field(statuses + counts, 2 * expected)
    end
  end

  def stock_card_status
    if date
      expected_entries, entries = entry_counts['stock_cards'] ||= [
        StockCard.count                                    + stock_card_statuses.select{ |s| s.have? }.length,
        stock_card_statuses.reject{|s| s.have.nil?}.length + stock_card_statuses.reject{ |s| s.have? && s.used_correctly.nil?}.length
      ]
      reporting_status_field(entries, expected_entries)
    end
  end

  def entry_counts
    @entry_counts ||= {}
  end

  def entry_counts=(e)
    @entry_counts = e
  end

  def cold_chain_entries
    entry_counts['cold_chain'] ||= 
      [health_center.stock_room.fridges.length, 
        FridgeStatus.count(:conditions => { :fridge_id => health_center.stock_room.fridges, :user_id => user_id, :reported_at => date.beginning_of_day..date.end_of_day })] 
  end
  
  def cold_chain_status
    if date
      expected_entries, entries = *cold_chain_entries
      reporting_status_field(entries, expected_entries)
    end
  end

  def tally_status(tally_klass)
    conditions = { :conditions => { :health_center_id => health_center, :date_period => epi_month } }
    entries = entry_counts[tally_klass.name] ||= tally_klass.count(conditions) 
    expected_entries = tally_klass.expected_entries.length
    reporting_status_field(entries, expected_entries)
  end         

  def status_by_table(table=nil)
    @status ||= returning ActiveSupport::OrderedHash.new do |h|
      self.class.tally_hash.sort.each do |k, v|
        h[k] = epi_data_ready? ? tally_status(k.constantize) : REPORT_NOT_VISITED
      end

      self.class.inventory_screen_hash.sort.each do |k, v|
        h[v] = visited ? inventory_status(k) : REPORT_NOT_VISITED
      end
      
      h['GeneralEquipment']   = visited ? equipment_status  : REPORT_NOT_VISITED
      h['ColdChainEquipment'] = visited ? cold_chain_status : REPORT_NOT_VISITED
      h['StockCardEquipment'] = visited ? stock_card_status : REPORT_NOT_VISITED
    end
    table.nil? ? @status : @status[table]    
  end

  def overall_status
    st = status_by_table_with_visit.values.reject{|v| v == REPORT_NOT_VISITED || v == REPORT_IRRELEVANT}.uniq
    return st.first if st.length == 1
    return REPORT_INCOMPLETE
  end

  def first_unvisited_step
    status_by_table.detect{|k,v| [REPORT_INCOMPLETE, REPORT_NOT_DONE].include?(v)}.maybe.first
  end
  
  private

  def reporting_status_field(entries, expected_entries)
    if expected_entries == 0
      REPORT_IRRELEVANT
    elsif entries && entries >= expected_entries
      REPORT_COMPLETE
    elsif entries.to_i == 0
      REPORT_NOT_DONE
    else
      REPORT_INCOMPLETE
    end
  end

  def combined_status(*values)
    [ REPORT_NOT_VISITED, REPORT_NOT_DONE, REPORT_COMPLETE ].each do |status|
      return status if values.all?{|v| v == status }
    end
    REPORT_INCOMPLETE
  end

  public
  
  def epi_month
    if !visit_month.blank?
      year, month = visit_month.split('-', 2)
      if month == '01'
        "%04d-%s" % [year.to_i - 1, '12']
      else
        "%s-%02d" % [year, month.to_i - 1]
      end
    end
  end

  def after_save
    find_or_create_inventory_records.each(&:save) if visited?
  end

  def ideal_stock
    inventories = find_or_create_inventory_records

    Hash[*inventories.map { |i| [i.inventory_type, i.package_counts_by_package_code] }.flatten].merge(
      {
        :ideal     => health_center ? IdealStockAmount.all(:conditions => { :stock_room_id => health_center.stock_room.id },
                                                            :include => :package, :order => 'packages.position').group_by(&:package) : nil,
      })
  end
  
  def equipment_count_and_status_by_type
    counts, statuses = find_or_initialize_equipment
    Hash[*counts.zip(statuses).map { |c,s| [c.equipment_type, [c, s]] }.flatten_once]
  end

  def find_or_initialize_equipment
    equipment_types = EquipmentType.all.sort
    equipment_counts = equipment_types.collect{|type| 
      EquipmentCount.find_or_initialize_by_equipment_type_id_and_stock_room_id_and_health_center_visit_id(
        type.id,
        self.health_center ? self.health_center.stock_room.id : nil,
        self.id) }
    
    equipment_statuses = equipment_types.collect{|type| 
      EquipmentStatus.find_or_initialize_by_equipment_type_id_and_stock_room_id_and_health_center_visit_id(
        type.id,
        self.health_center ? self.health_center.stock_room.id : nil,
        self.id) }
      
    return equipment_counts, equipment_statuses
  end    
  
  def find_or_initialize_fridge_statuses(options = {})
    fridges = health_center ? health_center.stock_room.fridges : [nil]
    if options[:min_count]
      fridges.length.upto(options[:min_count] - 1) { |i| fridges << nil }
    end
    fridges.collect{|fridge| 
        FridgeStatus.find_by_reported_at_and_fridge_id_and_user_id(visited_at && (visited_at.beginning_of_day..visited_at.end_of_day), fridge, user_id) ||
          FridgeStatus.new(:reported_at => visited_at, :fridge => fridge, :user => field_coordinator)
      }
  end    
  
  def find_or_initialize_stock_card_statuses
    stock_cards = StockCard.all.sort
    stock_card_statuses = stock_cards.collect{|stock_card|
      StockCardStatus.find_or_initialize_by_stock_card_id_and_stock_room_id_and_health_center_visit_id(
        stock_card.id,
        self.health_center ? self.health_center.stock_room.id : nil,
        self.id) }
  end

  def find_or_create_inventory_records
    @inventory ||= Inventory.types.map { |t|
      Inventory.find_or_initialize_by_date_and_stock_room_id_and_inventory_type(
          self.visited_at ? self.visited_at.to_date : Date.today,
          self.health_center ? self.health_center.stock_room.id : nil,
          t).tap { |i| i.user_id ||= self.user_id }
    }
  end
end


