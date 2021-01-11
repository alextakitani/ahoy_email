# dependencies
require "active_support"
require "addressable/uri"
require "nokogiri"
require "safely/core"

# stdlib
require "openssl"
require "base64"

# subscribers
require "ahoy_email/hit_subscriber"
require "ahoy_email/message_subscriber"
require "ahoy_email/redis_subscriber"

# modules
require "ahoy_email/processor"
require "ahoy_email/tracker"
require "ahoy_email/observer"
require "ahoy_email/mailer"
require "ahoy_email/version"
require "ahoy_email/engine" if defined?(Rails)

module AhoyEmail
  mattr_accessor :secret_token, :default_options, :subscribers, :invalid_redirect_url, :track_method, :api, :preserve_callbacks, :save_token, :allow_unverified_opens
  mattr_writer :message_model

  self.api = false

  self.default_options = {
    # message history
    message: false,
    mailer: -> { "#{self.class.name}##{action_name}" },
    user: -> { (defined?(@user) && @user) || (respond_to?(:params) && params && params[:user]) || (message.to.try(:size) == 1 ? (User.find_by(email: message.to.first) rescue nil) : nil) },
    extra: {},

    # utm tagging
    utm_params: false,
    utm_source: -> { mailer_name },
    utm_medium: "email",
    utm_term: nil,
    utm_content: nil,
    utm_campaign: -> { action_name },

    # events
    open: false,
    click: false,
    campaign: -> { "#{self.class.name}##{action_name}" },
    url_options: {},
    unsubscribe_links: false
  }

  self.track_method = lambda do |data|
    message = data[:message]

    ahoy_message = AhoyEmail.message_model.new
    ahoy_message.to = Array(message.to).join(", ") if ahoy_message.respond_to?(:to=)
    ahoy_message.user = data[:user] if ahoy_message.respond_to?(:user=)

    ahoy_message.mailer = data[:mailer] if ahoy_message.respond_to?(:mailer=)
    ahoy_message.subject = message.subject if ahoy_message.respond_to?(:subject=)
    ahoy_message.content = message.encoded if ahoy_message.respond_to?(:content=)

    AhoyEmail::Processor::UTM_PARAMETERS.each do |k|
      ahoy_message.send("#{k}=", data[k.to_sym]) if ahoy_message.respond_to?("#{k}=")
    end

    ahoy_message.token = data[:token] if AhoyEmail.save_token && ahoy_message.respond_to?(:token=)

    ahoy_message.campaign_id = data[:campaign_id] if ahoy_message.respond_to?(:campaign_id=)

    ahoy_message.assign_attributes(data[:extra] || {})

    ahoy_message.sent_at = Time.now
    ahoy_message.save!

    ahoy_message
  end

  self.subscribers = [HitSubscriber]

  self.preserve_callbacks = []

  self.message_model = -> { ::Ahoy::Message }

  def self.message_model
    model = defined?(@@message_model) && @@message_model
    model = model.call if model.respond_to?(:call)
    model
  end

  self.save_token = false

  self.allow_unverified_opens = false

  # private
  def self.signature(token:, campaign_id:, url: nil)
    data = [token, campaign_id]
    data << url if url

    # encode and join with a character outside encoding
    data = data.map { |v| Base64.strict_encode64(v.to_s) }.join("|")

    raise "Secret token is empty" unless AhoyEmail.secret_token

    Base64.urlsafe_encode64(OpenSSL::HMAC.digest("SHA256", AhoyEmail.secret_token, data), padding: false)
  end
end

ActiveSupport.on_load(:action_mailer) do
  include AhoyEmail::Mailer
  register_observer AhoyEmail::Observer
  Mail::Message.send(:attr_accessor, :ahoy_data, :ahoy_message, :ahoy_campaign)
end
