module Ahoy
  class Url < ActiveRecord::Base
    self.table_name = "ahoy_urls"

    belongs_to :campaign, class_name: "Ahoy::Campaign"
  end
end
