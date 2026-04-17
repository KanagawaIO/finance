module Kanagawa
  module DashboardHelper
    def kanagawa_brl(cents)
      # Mock-only BRL formatter. Replaces with host Money when models arrive.
      number_to_currency(cents.to_d / 100, unit: "R$ ", separator: ",", delimiter: ".", format: "%u%n")
    end

    def kanagawa_pct(numerator_cents, denominator_cents, decimals: 1)
      return "0%" if denominator_cents.to_i.zero?
      number_to_percentage((numerator_cents.to_d / denominator_cents) * 100, precision: decimals, separator: ",")
    end

    def kanagawa_relative_date(date)
      days = (date - Date.current).to_i
      case days
      when 0 then t("kanagawa.dashboard.relative.today")
      when 1 then t("kanagawa.dashboard.relative.tomorrow")
      when -1 then t("kanagawa.dashboard.relative.yesterday")
      when 2..Float::INFINITY then t("kanagawa.dashboard.relative.in_days", count: days)
      else t("kanagawa.dashboard.relative.days_ago", count: days.abs)
      end
    end

    def kanagawa_severity_classes(severity)
      case severity.to_sym
      when :destructive then { border: "border-red-200", bg: "bg-red-50", text: "text-red-700", pill: "bg-red-100 text-red-800" }
      when :warning     then { border: "border-yellow-200", bg: "bg-yellow-50", text: "text-yellow-700", pill: "bg-yellow-100 text-yellow-800" }
      when :success     then { border: "border-green-200", bg: "bg-green-50", text: "text-green-700", pill: "bg-green-100 text-green-800" }
      else                   { border: "border-primary", bg: "bg-container-inset", text: "text-secondary", pill: "bg-gray-100 text-gray-800" }
      end
    end

    def kanagawa_obligation_status(applied_cents, target_cents, cap: false)
      ratio = applied_cents.to_d / [ target_cents, 1 ].max
      if cap
        return :destructive if ratio > 1
        return :warning     if ratio > 0.9
        :success
      else
        return :destructive if ratio < 0.5
        return :warning     if ratio < 1
        :success
      end
    end
  end
end
