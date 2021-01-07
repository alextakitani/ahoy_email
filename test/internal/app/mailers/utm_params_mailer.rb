class UtmParamsMailer < ApplicationMailer
  save_history only: [:history]
  add_utm_params except: [:welcome]

  def welcome
    mail_html('<a href="https://example.org">Test</a>')
  end

  def basic
    mail_html('<a href="https://example.org">Test</a>')
  end

  def history
    mail_html('<a href="https://example.org">Test</a>')
  end

  def array_params
    mail_html('<a href="https://example.org?baz[]=1&amp;baz[]=2">Hi<a>')
  end
end
