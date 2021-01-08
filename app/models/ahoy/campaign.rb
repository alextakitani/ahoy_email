module Ahoy
  class Campaign < ActiveRecord::Base
    self.table_name = "ahoy_campaigns"

    has_many :urls, class_name: "Ahoy::Url"
  end
end
