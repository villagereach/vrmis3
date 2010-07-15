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

class JsonVisitDataSource < DataSource
  ContentType="application/json"

  def description
    'Offline'
  end
  
  def data_to_params(submission)
    json = JSON.parse(submission.data)

    visit = json['health_center_visit']
    
    submission.created_on = visit.delete('last_edited')

    if fc = User.find_by_name(visit.delete('field_coordinator'))
      visit['user_id'] = fc.id
    end

    params = { 'health_center_visit' => visit }

    params['health_center_visit']['reason_for_not_visiting'] = params['health_center_visit'].delete('non_visit_reason')
    params['health_center_visit']['vehicle_code'] = params['health_center_visit'].delete('vehicle_id')
    params['health_center_visit'].delete('epi_month')

    HealthCenterVisit.tables.each do |t|
      params[t.table_name.singularize] = t.json_to_params(json)
    end

    normalize_parameters(params)
  end
end


