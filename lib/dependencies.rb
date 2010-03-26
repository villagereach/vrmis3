# Shamelessly stolen from Rails Engines. -joel

# One of the magic features that that engines plugin provides is the ability to
# override selected methods in controllers and helpers from your application.
# This is achieved by trapping requests to load those files, and then mixing in
# code from plugins (in the order the plugins were loaded) before finally loading
# any versions from the main +app+ directory.
#
# The behaviour of this extension is output to the log file for help when
# debugging.
#
# == Example
#
# A plugin contains the following controller in <tt>plugin/app/controllers/my_controller.rb</tt>:
#
#   class MyController < ApplicationController
#     def index
#       @name = "HAL 9000"
#     end
#     def list
#       @robots = Robot.find(:all)
#     end
#   end
#
# In one application that uses this plugin, we decide that the name used in the
# index action should be "Robbie", not "HAL 9000". To override this single method,
# we create the corresponding controller in our application 
# (<tt>RAILS_ROOT/app/controllers/my_controller.rb</tt>), and redefine the method:
#
#   class MyController < ApplicationController
#     def index
#       @name = "Robbie"
#     end
#   end
#
# The list method remains as it was defined in the plugin controller.
#
# The same basic principle applies to helpers, and also views and partials (although
# view overriding is performed in Engines::RailsExtensions::Templates; see that
# module for more information).
#
# === What about models?
#
# Unfortunately, it's not possible to provide this kind of magic for models.
# The only reason why it's possible for controllers and helpers is because
# they can be recognised by their filenames ("whatever_controller", "jazz_helper"),
# whereas models appear the same as any other typical Ruby library ("node",
# "user", "image", etc.). 
#
# If mixing were allowed in models, it would mean code mixing for *every* 
# file that was loaded via +require_or_load+, and this could result in
# problems where, for example, a Node model might start to include 
# functionality from another file called "node" somewhere else in the
# <tt>$LOAD_PATH</tt>.
#
# One way to overcome this is to provide model functionality as a module in
# a plugin, which developers can then include into their own model
# implementations.
#
# Another option is to provide an abstract model (see the ActiveRecord::Base
# documentation) and have developers subclass this model in their own
# application if they must.
#
# ---
#
# The Engines::RailsExtensions::Dependencies module includes a method to
# override Dependencies.require_or_load, which is called to load code needed
# by Rails as it encounters constants that aren't defined.
#
# This method is enhanced with the code-mixing features described above.
#
module Olmis::Dependencies
  def self.included(base) #:nodoc:
    base.class_eval { alias_method_chain :require_or_load, :olmis_additions }
  end

  # Attempt to load the given file from any plugins, as well as the application.
  # This performs the 'code mixing' magic, allowing application controllers and
  # helpers to override single methods from those in plugins.
  # If the file can be found in any plugins, it will be loaded first from those
  # locations. Finally, the application version is loaded, using Ruby's behaviour
  # to replace existing methods with their new definitions.
  #
  # If <tt>Engines.disable_code_mixing == true</tt>, the first controller/helper on the
  # <tt>$LOAD_PATH</tt> will be used (plugins' +app+ directories are always lower on the
  # <tt>$LOAD_PATH</tt> than the main +app+ directory).
  #
  # If <tt>Engines.disable_application_code_loading == true</tt>, controllers will
  # not be loaded from the main +app+ directory *if* they are present in any
  # plugins.
  #
  # Returns true if the file could be loaded (from anywhere); false otherwise -
  # mirroring the behaviour of +require_or_load+ from Rails (which mirrors
  # that of Ruby's own +require+, I believe).
  def require_or_load_with_olmis_additions(file_name, const_path=nil)
    file_loaded = false

    # try and load the plugin code first
    # can't use model, as there's nothing in the name to indicate that the file is a 'model' file
    # rather than a library or anything else.
    [['controllers','_controller'], ['helpers','_helper'], ['models', '']].each do |dir, suffix| 
      # if we recognise this type
      # (this regexp splits out the module/filename from any instances of app/#{type}, so that
      #  modules are still respected.)
      if file_name =~ /^(.*app\/#{dir}\/)+(.*#{suffix})(\.rb)?$/
        base_name = $2

        plugin_file_name = File.expand_path(File.join('vendor','plugins', 'olmis', 'lib', dir, base_name))
        if File.file?("#{plugin_file_name}.rb")
          file_loaded = true if require_or_load_without_olmis_additions(plugin_file_name, const_path)
        end
    
        # Ensure we are only loading from the /app directory at this point
        app_file_name = File.join(RAILS_ROOT, 'app', dir, base_name)
        if File.file?("#{app_file_name}.rb")
          file_loaded = true if require_or_load_without_olmis_additions(app_file_name, const_path)
        end
      end 
    end

    # if we managed to load a file, return true. If not, default to the original method.
    # Note that this relies on the RHS of a boolean || not to be evaluated if the LHS is true.
    file_loaded || require_or_load_without_olmis_additions(file_name, const_path)
  end  
end

module ActiveSupport::Dependencies #:nodoc:
  include Olmis::Dependencies
end
