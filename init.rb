require 'dispatcher' unless defined?(::Dispatcher)

require 'ick'
require 'stringex'

Dir.glob(File.join(File.dirname(__FILE__), 'initializers', '*.rb')) do |f|
  require f
end

ActionController::Base.append_view_path(File.dirname(__FILE__) + '/lib/views')

Dir.glob(File.join(File.dirname(__FILE__), 'lib', '*', '*.rb')) do |f|
  require f
end

Dispatcher.to_prepare do
end
