puts "Olmis init"

require 'dispatcher' unless defined?(::Dispatcher)

Dispatcher.to_prepare do
  ActionController::Base.append_view_path(File.dirname(__FILE__) + '/lib/views')
end
