module Kanagawa
  module NavInjector
    extend ActiveSupport::Concern

    included do
      after_action :inject_kanagawa_nav
    end

    private
      def inject_kanagawa_nav
        return unless response.content_type&.include?("text/html")
        return unless response.body.present?

        nav_li = kanagawa_nav_li_html

        # Inject into the desktop nav <ul class="space-y-0.5"> — the only <ul> with
        # that class in the layout. Append our <li> before its closing </ul>.
        # If upstream changes the nav structure and the regex no longer matches,
        # the app keeps working — the nav item simply won't appear.
        response.body = response.body.sub(
          /(<ul class="space-y-0\.5">.*?)(<\/ul>)/m,
          "\\1#{nav_li}\\2"
        )
      end

      def kanagawa_nav_li_html
        active = request.path.start_with?("/b")

        indicator_class = active ? "bg-nav-indicator" : ""
        icon_wrapper_class = active ? "bg-container shadow-xs text-primary" : "group-hover:bg-surface-hover text-secondary"
        label_class = active ? "text-primary" : "text-secondary"
        label = I18n.t("kanagawa.nav.label", default: "Business")

        # Temporary diagnostic: embed the resolved locale and whether the
        # engine's pt-BR translation resolves. Remove once the i18n plumbing
        # is confirmed working.
        debug_locale = I18n.locale
        debug_pt_br_translation = I18n.t("kanagawa.nav.label", locale: :"pt-BR", default: "MISSING")
        debug_pt_translation    = I18n.t("kanagawa.nav.label", locale: :pt,      default: "MISSING")

        # Mirrors the exact markup of app/views/layouts/shared/_nav_item.html.erb
        # Icon: Lucide "briefcase" (24x24)
        <<~HTML.gsub("\n", "")
          <li data-kanagawa-debug-locale="#{ERB::Util.html_escape(debug_locale)}" data-kanagawa-debug-ptbr="#{ERB::Util.html_escape(debug_pt_br_translation)}" data-kanagawa-debug-pt="#{ERB::Util.html_escape(debug_pt_translation)}">
            <a href="/b" class="space-y-1 group block relative pb-1">
              <div class="grow flex flex-col lg:flex-row gap-1 items-center">
                <div class="w-4 h-1 lg:w-1 lg:h-4 rounded-bl-sm rounded-br-sm lg:rounded-tr-sm lg:rounded-br-sm lg:rounded-bl-none #{indicator_class}"></div>
                <div class="w-8 h-8 flex items-center justify-center mx-auto rounded-lg #{icon_wrapper_class}">
                  <svg xmlns="http://www.w3.org/2000/svg" width="20" height="20" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"><path d="M16 20V4a2 2 0 0 0-2-2h-4a2 2 0 0 0-2 2v16"/><rect width="20" height="14" x="2" y="6" rx="2"/></svg>
                </div>
              </div>
              <div class="grow flex justify-center lg:pl-2">
                <p class="font-medium text-[11px] #{label_class}">#{ERB::Util.html_escape(label)}</p>
              </div>
            </a>
          </li>
        HTML
      end
  end
end
