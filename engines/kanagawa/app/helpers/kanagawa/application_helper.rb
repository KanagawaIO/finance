module Kanagawa
  module ApplicationHelper
    # Fixes the view-context side of the isolated-namespace URL helper
    # problem: the host's shared layout and partials (rendered inside
    # engine-controller actions) call bare *_path / *_url helpers that the
    # engine's own routes module doesn't define. See the delegator module
    # for details.
    include Kanagawa::MainAppRouteDelegator
  end
end
