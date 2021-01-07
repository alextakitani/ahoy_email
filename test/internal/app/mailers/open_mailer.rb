class OpenMailer < ApplicationMailer
  save_history
  track_events open: true, click: false, only: [:basic]

  def welcome
    mail_html('Hi')
  end

  def basic
    mail_html('Hi')
  end
end
