module Kanagawa
  class Engine < ::Rails::Engine
    isolate_namespace Kanagawa

    # Use the main app's layout so engine pages look native
    config.to_prepare do
      Kanagawa::ApplicationController.layout "application"
    end

    # Register engine migrations alongside the main app
    initializer "kanagawa.migrations" do |app|
      unless app.root.to_s.match?(root.to_s)
        config.paths["db/migrate"].expanded.each do |expanded_path|
          app.config.paths["db/migrate"] << expanded_path
        end
      end
    end

    # Inject nav item into the layout without modifying any Sure HTML
    initializer "kanagawa.nav_injection" do
      ActiveSupport.on_load(:action_controller_base) do
        include Kanagawa::NavInjector
      end
    end
  end
end
