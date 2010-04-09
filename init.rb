require 'dispatcher' unless defined?(::Dispatcher)

require 'ick'
require 'stringex'

Dir.glob(File.join(File.dirname(__FILE__), 'initializers', '*.rb')) do |f|
  require f
end

ActionController::Base.append_view_path(File.dirname(__FILE__) + '/lib/views')

require File.join(File.dirname(__FILE__), 'lib', 'dependencies.rb')

Dir.glob(File.join(File.dirname(__FILE__), 'lib', 'mixins', '*.rb')) do |f|
  require f
end

Dispatcher.to_prepare do
end

# For development, remove this plugin's files from load_once_paths. This avoids errors such
# as "A copy of UsersController has been removed from the module tree but is still active!"
ActiveSupport::Dependencies.load_once_paths.delete(File.join(File.dirname(__FILE__), 'lib')) if config.environment == 'development'
