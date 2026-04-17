module Kanagawa
  # Mixed into Kanagawa::ApplicationController and Kanagawa::ApplicationHelper
  # so any bare *_path / *_url helper call that the isolated engine routes
  # don't define transparently delegates to main_app. Lets the host's shared
  # layout and concerns (Onboardable, Breadcrumbable, etc.) render inside
  # engine controllers without modifying the Sure host.
  #
  # Ruby resolves defined methods before method_missing, so engine-native
  # route helpers (e.g. future organs_path) keep resolving to the engine.
  # Only the one collision where both sides define the same name needs an
  # explicit shadow — today that's just root_path/root_url.
  #
  # File lives directly under app/controllers/kanagawa/ so Zeitwerk maps
  # it to Kanagawa::MainAppRouteDelegator. (Rails' concerns/ collapse only
  # applies to the host's top-level app/controllers/concerns directory —
  # engines don't get that automatically, so we skip the nested folder.)
  module MainAppRouteDelegator
    extend ActiveSupport::Concern

    # Engine also defines root_path via its `root "home#index"`. The host
    # layout expects the main app's root (/), so shadow both versions.
    def root_path(*args, **kwargs)
      main_app.root_path(*args, **kwargs)
    end

    def root_url(*args, **kwargs)
      main_app.root_url(*args, **kwargs)
    end

    # Helpers called from host controller concerns (Onboardable, Invitable,
    # etc.). They're INHERITED from ::ApplicationController via
    # Rails.application.routes.url_helpers, so method_missing doesn't
    # intercept — yet their internal url_for resolves against the engine's
    # isolated router and raises UrlGenerationError. Shadow each one with a
    # version that goes through main_app explicitly.
    #
    # Note: the view-context side is handled by method_missing below (the
    # engine's routes.url_helpers module doesn't define these names, so
    # bare calls from host-layout partials naturally fall through).
    HOST_CONTROLLER_HELPERS = %i[
      new_registration_path new_registration_url
      new_session_path      new_session_url
      new_password_reset_path new_password_reset_url
      new_email_confirmation_path new_email_confirmation_url
      onboarding_path onboarding_url
      trial_onboarding_path trial_onboarding_url
      upgrade_subscription_path upgrade_subscription_url
    ].freeze

    HOST_CONTROLLER_HELPERS.each do |helper|
      define_method(helper) do |*args, **kwargs|
        main_app.public_send(helper, *args, **kwargs)
      end
    end

    def method_missing(name, *args, **kwargs, &block)
      if name.to_s.end_with?("_path", "_url") && main_app.respond_to?(name)
        main_app.public_send(name, *args, **kwargs, &block)
      else
        super
      end
    end

    def respond_to_missing?(name, include_private = false)
      (name.to_s.end_with?("_path", "_url") && main_app.respond_to?(name)) || super
    end
  end
end
