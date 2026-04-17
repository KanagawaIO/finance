module Kanagawa
  class ApplicationController < ::ApplicationController
    # Inherits auth, Current.user, Current.family, all host helpers.

    # Engine lives under `isolate_namespace Kanagawa`, so bare *_path /
    # *_url helpers from the host's ApplicationController concerns (e.g.
    # Onboardable#redirectable_path?) and from the host's shared layout
    # don't find the main_app routes. The delegator catches those calls and
    # forwards them to main_app.
    include Kanagawa::MainAppRouteDelegator

    # isolate_namespace also means engine helpers under
    # engines/kanagawa/app/helpers/kanagawa/ aren't auto-discovered by the
    # host's `helper :all`. Include them explicitly so every Kanagawa
    # controller's views have `kanagawa_brl`, `kanagawa_relative_date`, and
    # the main_app route delegation applied at view context level.
    helper Kanagawa::ApplicationHelper
    helper "kanagawa/dashboard"
  end
end
