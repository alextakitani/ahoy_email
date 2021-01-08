module AhoyEmail
  class Tracker
    attr_reader :message

    def initialize(message)
      @message = message
    end

    def perform
      Safely.safely do
        # perform_deliveries check still needed in observer
        if message.perform_deliveries
          if message.ahoy_data
            data = message.ahoy_data.merge(message: message)
            message.ahoy_message = AhoyEmail.track_method.call(data)
          end

          if message.ahoy_campaign
            message.ahoy_campaign.increment!(:total_sent)
          end
        end
      end
    end
  end
end
