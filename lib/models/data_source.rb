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

class DataSource < ActiveRecord::Base
  def file_data=(file_data)
    @file_data = file_data

    # Determine the file type.
    @file_type ||= case file_data.content_type
                   when /^(application|text)\/xml$/
                     XFORMS_FILETYPE
                   when "application/vnd.ms-excel"
                     EXCEL_FILETYPE
                   when "application/octet-stream"
                     # IE does not send the correct MIME type for binary files so we
                     # need to perform some forensics on it to see what type it is.
                     #
                     # ODK Collect also doesn't seem to send the correct MIME type.
                     file_header = file_data.read(8)
                     file_data.rewind
                     if file_header == EXCEL_MAGIC && file_data.original_filename.downcase =~ /\.xls$/
                       EXCEL_FILETYPE
                     elsif file_header[0,XML_MAGIC.length] == XML_MAGIC
                       XFORMS_FILETYPE
                     end
                   else
                     nil
                   end
  end


  def normalize_parameters(value)
    case value
    when Hash: 
      h = {}
      value.each { |k, v| h[k] = normalize_parameters(v) }
      h.with_indifferent_access
    when Array
      value.map { |e| normalize_parameters(e) }
    else
      value
    end
  end
  
  def self.[](s)
    type = s.constantize
    source = type.find(:first) || type.new
    source.save!
    source
  end
end



