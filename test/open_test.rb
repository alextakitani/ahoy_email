require_relative "test_helper"

class OpenTest < ActionDispatch::IntegrationTest
  def test_default
    message = OpenMailer.welcome.deliver_now
    refute_body "open.gif", message
  end

  def test_basic
    message = OpenMailer.basic.deliver_now
    assert_body "open.gif", message

    open_message(message)
    assert_response :success
    open_message(message)

    assert_equal 2, ahoy_campaign.total_opens
    assert_equal 1, ahoy_campaign.unique_opens
  end

  def test_subscriber
    with_subscriber(EmailSubscriber.new) do
      message = OpenMailer.basic.deliver_now
      open_message(message)

      assert_equal 1, $open_events.size
      open_event = $open_events.first
      assert open_event[:token]
    end
  end

  def test_message_subscriber
    AhoyEmail.save_token = true
    with_subscriber(AhoyEmail::MessageSubscriber) do
      message = OpenMailer.campaignless.deliver_now
      refute_body /\bc=/, message
      open_message(message)

      assert ahoy_message.opened_at
      assert_equal 0, Ahoy::Campaign.count
    end
  ensure
    AhoyEmail.save_token = false
  end

  def open_message(message)
    url = /src=\"([^"]+)\"/.match(message.body.decoded)[1]

    # unescape entities like browser does
    url = CGI.unescapeHTML(url)

    get url
  end
end
