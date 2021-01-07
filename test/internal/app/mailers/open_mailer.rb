class OpenMailer < ApplicationMailer
  save_message
  track_hits open: true, click: false, only: [:basic]

  def welcome
    mail_html('Hi')
  end

  def basic
    mail_html('Hi')
  end
end
