require_relative "test_helper"

class ClickTest < ActionDispatch::IntegrationTest
  def test_default
    message = ClickMailer.welcome.deliver_now
    refute_body "click", message
  end

  def test_basic
    message = ClickMailer.basic.deliver_now
    assert_body "click", message

    assert_equal 1, Ahoy::Campaign.count
    assert_equal 0, Ahoy::Url.count

    assert_equal "ClickMailer#basic", ahoy_campaign.name
    assert_equal 1, ahoy_campaign.total_sent

    click_link(message)
    assert_redirected_to "https://example.org"
    click_link(message)

    assert_equal 2, ahoy_campaign.total_clicks
    assert_equal 1, ahoy_campaign.unique_clicks

    assert_equal 1, Ahoy::Url.count
    assert_equal ahoy_campaign, ahoy_url.campaign
    assert_equal "https://example.org", ahoy_url.url
    assert_equal 2, ahoy_url.total_clicks
    assert_equal 1, ahoy_url.unique_clicks
  end

  def test_concurrency
    skip if defined?(Mongoid)

    ClickMailer # fix for autoload

    threads = []
    5.times do
      threads << Thread.new do
        message = ClickMailer.basic.deliver_now
        click_link(message)
        click_link(message)
      end
    end
    threads.map(&:join)

    assert_equal 10, ahoy_campaign.total_clicks
    assert_equal 5, ahoy_campaign.unique_clicks
  end

  def test_query_params
    message = ClickMailer.query_params.deliver_now
    assert_body "click", message

    click_link(message)
    assert_redirected_to "https://example.org?a=1&b=2"
    assert ahoy_message.clicked_at
  end

  def test_subscriber
    with_subscriber(EmailSubscriber.new) do
      message = ClickMailer.basic.deliver_now
      click_link(message)

      assert_equal 1, $click_events.size
      click_event = $click_events.first
      assert_equal "https://example.org", click_event[:url]
      assert_equal ahoy_message, click_event[:message]
      assert click_event[:token]
    end
  end

  def test_subscriber_class
    with_subscriber(EmailSubscriber) do
      message = ClickMailer.basic.deliver_now
      click_link(message)

      assert_equal 1, $click_events.size
      click_event = $click_events.first
      assert_equal "https://example.org", click_event[:url]
      assert_equal ahoy_message, click_event[:message]
      assert click_event[:token]
    end
  end

  def test_message_subscriber
    AhoyEmail.save_token = true
    with_subscriber(AhoyEmail::MessageSubscriber) do
      message = ClickMailer.campaignless.deliver_now
      refute_body /\bc=/, message
      click_link(message)

      assert ahoy_message.clicked_at
      assert_equal 0, Ahoy::Campaign.count
    end
  ensure
    AhoyEmail.save_token = false
  end

  def test_bad_signature
    message = ClickMailer.basic.deliver_now
    assert_body "click", message
    url = /a href=\"([^"]+)\"/.match(message.body.decoded)[1]
    get url.sub("signature=", "signature=bad")
    assert_redirected_to root_url
  end

  def test_missing_message
    with_subscriber(EmailSubscriber) do
      message = ClickMailer.basic.deliver_now
      token = ahoy_message.token
      Ahoy::Message.delete_all
      click_link(message)

      assert_equal 1, $click_events.size
      click_event = $click_events.first
      assert_equal "https://example.org", click_event[:url]
      assert_nil click_event[:message]
      assert_equal token, click_event[:token]
    end
  end

  def test_mailto
    message = ClickMailer.mailto.deliver_now
    assert_body '<a href="mailto:hi@example.org">', message
  end

  def test_app
    message = ClickMailer.app.deliver_now
    assert_body '<a href="fb://profile/33138223345">', message
  end

  def test_schemeless
    message = ClickMailer.schemeless.deliver_now
    assert_body "click", message
  end

  def test_conditional
    message = ClickMailer.conditional(false).deliver_now
    refute_body "click", message

    message = ClickMailer.conditional(true).deliver_now
    assert_body "click", message
  end

  def click_link(message)
    url = /href=\"([^"]+)\"/.match(message.body.decoded)[1]

    # unescape entities like browser does
    url = CGI.unescapeHTML(url)

    get url
  end
end
