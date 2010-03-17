# == Schema Information
# Schema version: 20100127014005
#
# Table name: data_sources
#
#  id         :integer(4)      not null, primary key
#  type       :string(255)     not null
#  created_at :datetime
#  updated_at :datetime
#

class AndroidOdkVisitDataSource < DataSource
  Magic = '<?xml'
  ContentType="application/xml"
  NR = "-"

  def description
    'Android'
  end

  def data_to_params(submission)
    xml = Nokogiri::XML(submission.data)

    submission.created_on = xml.xpath('/vrmis3/meta/date').text

    visits = xml.xpath('/vrmis3/hcvisit/*').reject { |n| ['epi','visit'].include?(n.name) }

    params = { :health_center_visit => Hash[*visits.map { |n| [n.name, n.text] }.flatten] }

    if fc = User.find_by_name(xml.xpath('/vrmis3/meta/field_coordinator/name').text) ||
            User.find_by_phone(xml.xpath('/vrmis3/meta/field_coordinator/phone').text)
      submission.user = fc
    end

    if vfc = User.find_by_name(params[:health_center_visit].delete('visiting_field_coordinator'))
      params[:health_center_visit][:user_id] = vfc.id
    elsif fc
      params[:health_center_visit][:user_id] = fc.id
    end

    params[:health_center_visit]['visit_month'] = params[:health_center_visit]['visited_at'][0,7] if params[:health_center_visit]['visit_month'].blank?
    params[:health_center_visit][:reason_for_not_visiting] = params[:health_center_visit].delete('non_visit_reason')
    params[:health_center_visit][:vehicle_code] = params[:health_center_visit].delete('vehicle_id')
    params[:health_center_visit].delete('epi_month')

    # HACK: Until JavaRosa supports itemsets (i.e., dynamic selection lists), copy the health center to the correct location in the parameter list
    health_center = xml.xpath('/vrmis3/location/health_center').text
    params[:health_center_visit]['health_center'] = health_center.sub(/-\d+$/,'')  # HACK: strip any ID that was appended, i.e., to avoid problems with duplicate HC names in the ODK form

    # NOTE: EPI data not handled in ODK forms

    xml.xpath('/vrmis3/hcvisit/visit/inventory/*').find_all{|n| n.name.starts_with?('item_')}.each do |inv|
      product = inv.name[5..-1]

      params[:inventory_counts] ||= {}
      params[:inventory_counts][product] ||= { }

      inv.xpath('*').each do |type|
        quantity = type.xpath('./qty').text

        params[:inventory_counts][product][type.name]         = quantity == NR ? nil : quantity
        params[:inventory_counts][product][type.name + '/NR'] = quantity == NR ?   1 : 0
      end
    end

    xml.xpath('/vrmis3/hcvisit/visit/general/*').find_all{|n| n.name.starts_with?('item_')}.each do |equip|
      params[:equipment_count] ||= {}
      params[:equipment_status] ||= {}

      equipment = equip.name[5..-1]
      quantity = equip.xpath('./qty').text

      params[:equipment_count][equipment] = { 
        'quantity'    => quantity == NR ? nil : quantity,
        'quantity/NR' => quantity == NR ?   1 : 0
      }

      params[:equipment_status][equipment] = { 
        'status_code' => equip.xpath('./status').text,
        'notes'       => equip.xpath('./notes').text,
      }
    end

    xml.xpath("/vrmis3/location/fridges/hc-#{health_center}/*").each do |fridge|
      params[:fridge_status] ||= {}
      code = fridge['code'].to_s
      temp = fridge.xpath('./temp').text
      params[:fridge_status][fridge['code'].to_s] = {
        "temperature"    => temp,
        "temperature/NR" => temp == NR ? 1 : 0,
        "status_code" => fridge.xpath('./status').text,
        "notes" => fridge.xpath('./notes').text,
      }
    end

    xml.xpath('/vrmis3/hcvisit/visit/stock_cards/*').find_all{|n| n.name.starts_with?('item_')}.each do |card|
      params[:stock_card_status] ||= {}

      stock_card = card.name[5..-1]

      params[:stock_card_status][stock_card] = {
        'have'           => card.xpath('./have').text,
        'used_correctly' => card.xpath('./use').text
      }
    end

    return normalize_parameters(params)
  end

end
