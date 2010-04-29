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

class WebVisitDataSource < DataSource
  def description
    'Web'
  end
  
  def data_to_params(submission)
    if submission.content_type == 'application/x-www-form-urlencoded' 
      params = Rack::Utils::parse_nested_query(submission.data)
    else
      env = { 
        'CONTENT_TYPE' => submission.content_type, 
        'CONTENT_LENGTH' => submission.data.length, 
        'rack.input' => StringIO.new(submission.data) 
      }

      params = Rack::Utils::Multipart::parse_multipart(env)
    end

    HealthCenterVisit.tables.each do |t|
      params[t.table_name.singularize] = t.web_to_params(params)
    end
    
    normalize_parameters(params)
  end
end


