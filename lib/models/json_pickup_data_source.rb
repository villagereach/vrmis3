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

class JsonPickupDataSource < DataSource
  ContentType = "application/json"

  def description
    'Offline'
  end
  
  def data_to_params(submission)
    params = { :inventory => JSON.parse(submission.data) }
    normalize_parameters(params)
  end
end
