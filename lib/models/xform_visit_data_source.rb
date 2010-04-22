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

    submission.created_on = xml.xpath('/olmis/meta/date').text
    
    visits = xml.xpath('/olmis/hcvisit/*').reject { |n| n.name == 'epi' || n.name == 'visit' }
    
    params = { :health_center_visit => Hash[*visits.map { |n| [n.name, n.text] }.flatten] }
    
    if fc = User.find_by_name(xml.xpath('/olmis/meta/field_coordinator').text)
      params[:health_center_visit][:user_id] = fc.id
    end

    params[:health_center_visit][:reason_for_not_visiting] = params[:health_center_visit].delete('non_visit_reason')
    params[:health_center_visit][:vehicle_code] = params[:health_center_visit].delete('vehicle_id')
    params[:health_center_visit].delete('epi_month')

    HealthCenterVisit.tables.each do |t|
      params[t.table_name.singularize] = t.xforms_to_params(xml)
    end

    return normalize_parameters(params)
  end
end


