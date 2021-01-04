module Ahoy
  class Counter < ActiveRecord::Base
    self.table_name = "ahoy_counters"
  end
end
