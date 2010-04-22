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

    submission.created_on = xml.xpath('/olmis/meta/date').text

    visits = xml.xpath('/olmis/hcvisit/*').reject { |n| ['epi','visit'].include?(n.name) }

    params = { :health_center_visit => Hash[*visits.map { |n| [n.name, n.text] }.flatten] }

    if fc = User.find_by_name(xml.xpath('/olmis/meta/field_coordinator/name').text) ||
            User.find_by_phone(xml.xpath('/olmis/meta/field_coordinator/phone').text)
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
    health_center = xml.xpath('/olmis/location/health_center').text
    params[:health_center_visit]['health_center'] = health_center.sub(/-\d+$/,'')  # HACK: strip any ID that was appended, i.e., to avoid problems with duplicate HC names in the ODK form

    HealthCenterVisit.tables.each do |t|
      params[t.table_name.singularize] = t.odk_to_params(xml)
    end

    return normalize_parameters(params)
  end

end
