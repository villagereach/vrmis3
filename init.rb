require 'dispatcher' unless defined?(::Dispatcher)

Dispatcher.to_prepare do
  Dir.glob(File.join(File.dirname(__FILE__), 'lib', 'models', '*.rb')) do |f|
    require f
  end
  ActionController::Base.append_view_path(File.dirname(__FILE__) + '/lib/views')
end
