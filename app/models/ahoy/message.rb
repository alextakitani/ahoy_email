module Ahoy
  class Message < ActiveRecord::Base
    self.table_name = "ahoy_messages"

    belongs_to :user, polymorphic: true, optional: true

    # if campaign_id column present
    belongs_to :campaign, class_name: "Ahoy::Campaign", optional: true
  end
end
