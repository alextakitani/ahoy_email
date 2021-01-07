module AhoyEmail
  class MessageSubscriber
    def open(event)
      message = AhoyEmail.message_model.find_by(token: event[:token])
      if message && !message.opened_at
        message.opened_at = Time.now
        message.save!
      end
    end

    def click(event)
      message = AhoyEmail.message_model.find_by(token: event[:token])
      if message && !message.clicked_at
        message.clicked_at = Time.now
        message.opened_at ||= message.clicked_at if message.respond_to?(:opened_at=)
        message.save!
      end
    end
  end
end
