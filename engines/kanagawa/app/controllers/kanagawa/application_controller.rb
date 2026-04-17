module Kanagawa
  class ApplicationController < ::ApplicationController
    # Inherits auth, Current.user, Current.family, all helpers.

    # isolate_namespace on the engine means engine helpers aren't
    # auto-discovered by the host's `helper :all`. Pull them in explicitly
    # (string form defers resolution until Zeitwerk is ready) so every
    # Kanagawa controller's views have `kanagawa_brl`,
    # `kanagawa_relative_date`, etc.
    helper "kanagawa/dashboard"

    # The host's Onboardable concern (before_action on ApplicationController)
    # calls `new_registration_path`, `new_session_path`,
    # `new_password_reset_path` and `new_email_confirmation_path` to decide
    # whether to redirect to the onboarding flow. Those helpers resolve
    # against the current routing context, which for engine controllers is
    # Kanagawa::Engine's isolated route table — where those paths don't
    # exist, raising ActionController::UrlGenerationError on every /b
    # request. Delegate them to the main app so the host's concern keeps
    # working unchanged.
    %i[new_registration_path new_session_path new_password_reset_path new_email_confirmation_path].each do |helper|
      define_method(helper) { |*args, **kwargs| main_app.public_send(helper, *args, **kwargs) }
    end
  end
end
