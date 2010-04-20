# == Schema Information
# Schema version: 20100419182754
#
# Table name: data_sources
#
#  id         :integer(4)      not null, primary key
#  type       :string(255)     not null
#  created_at :datetime
#  updated_at :datetime
#

class XformVisitDataSource < DataSource
  Magic = '<?xml'
  ContentType="application/xml"

  def description
    'Xform'
  end
  
  def data_to_params(submission)
    xml = Nokogiri::XML(submission.data)

    submission.created_on = xml.xpath('/vrmis3/meta/date').text
    
    visits = xml.xpath('/vrmis3/hcvisit/*').reject { |n| n.name == 'epi' || n.name == 'visit' }
    
    params = { :health_center_visit => Hash[*visits.map { |n| [n.name, n.text] }.flatten] }
    
    if vfc = User.find_by_name(params[:health_center_visit].delete('visiting_field_coordinator'))
      params[:health_center_visit][:user_id] = vfc.id
    elsif fc = User.find_by_name(xml.xpath('/vrmis3/meta/field_coordinator').text)
      params[:health_center_visit][:user_id] = fc.id
    end

    params[:health_center_visit][:reason_for_not_visiting] = params[:health_center_visit].delete('non_visit_reason')
    params[:health_center_visit][:vehicle_code] = params[:health_center_visit].delete('vehicle_id')
    params[:health_center_visit].delete('epi_month')
    
    xml.xpath('/vrmis3/hcvisit/epi/*').each do |epi|
      params[epi.name.singularize.camelize] = Hash[*epi.xpath('./item').map { |n|
        [n['for'].to_s, n['val'].to_s] +
          (n['nr'].to_s == "true" ? [n['for'].to_s + '/NR', 1] : [])
      }.flatten]
    end

    xml.xpath('/vrmis3/hcvisit/visit/inventory/item').each do |inv|
      params[:inventory_counts] ||= {}
      params[:inventory_counts][inv['for'].to_s] ||= { }
      params[:inventory_counts][inv['for'].to_s][inv['type'].to_s] = inv['qty'].to_s
      params[:inventory_counts][inv['for'].to_s][inv['type'].to_s + '/NR'] = inv['nr'].to_s == 'true' ? 1 : 0
    end

    xml.xpath('/vrmis3/hcvisit/visit/general/item').each do |equip|
      params[:equipment_count] ||= {}
      params[:equipment_status] ||= {}
      
      params[:equipment_count][equip['for'].to_s] = { 
        'quantity' => equip['qty'].to_s,
        'quantity/NR' => equip['nr'].to_s == 'true' ? 1 : 0
      }

      params[:equipment_status][equip['for'].to_s] = { 
        'status_code' => equip['status'].to_s,
        'notes' => equip['notes'].to_s
      }
    end

    xml.xpath('/vrmis3/hcvisit/visit/cold_chain/fridges/fridge').each do |fridge|
      params[:fridge_status] ||= {}
      code = fridge['code'].to_s
      params[:fridge_status][fridge['code'].to_s] = {
        "temperature" => fridge['temp'].to_s,
        "temperature/NR" => fridge['nr'].to_s == 'true' ? 1 : 0,
        "status_code" => fridge['status'].to_s,
        "notes" => fridge['notes'].to_s
      }
    end

    xml.xpath('/vrmis3/hcvisit/visit/stock_cards/item').each do |card|
      params[:stock_card_status] ||= {}
      params[:stock_card_status][card['for'].to_s] = {
        'have'           => card['have'].to_s,
        'used_correctly' => card['use'].to_s
      }
    end

    return normalize_parameters(params)
  end
end


