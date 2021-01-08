class OpenMailer < ApplicationMailer
  track_hits open: true, only: [:basic]
  track_hits open: true, campaign: false, only: [:campaignless]
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
