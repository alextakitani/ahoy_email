class OpenMailer < ApplicationMailer
  track_hits open: true, click: false, only: [:basic]
  track_hits open: true, click: false, only: [:campaignless], campaign: false
  save_message only: [:campaignless]

  def welcome
    mail_html('Hi')
  end

  def basic
    mail_html('Hi')
  end

  def campaignless
    mail_html('Hi')
  end
end
