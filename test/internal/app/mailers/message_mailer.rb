class MessageMailer < ApplicationMailer
  save_message only: [:other, :no_deliver]

  after_action :prevent_delivery, only: [:no_deliver]

  def welcome
    mail
  end

  def other
    mail
  end

  def no_deliver
    mail
  end

  private

  def prevent_delivery
    mail.perform_deliveries = false
  end
end
