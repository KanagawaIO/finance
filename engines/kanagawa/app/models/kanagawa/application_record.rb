module Kanagawa
  class ApplicationRecord < ActiveRecord::Base
    self.abstract_class = true

    establish_connection(
      adapter: "sqlite3",
      database: Rails.root.join("storage", "kanagawa.sqlite3").to_s
    )
  end
end
