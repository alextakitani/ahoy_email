module Ahoy
  class MessagesController < ApplicationController
    filters = _process_action_callbacks.map(&:filter) - AhoyEmail.preserve_callbacks
    skip_before_action(*filters, raise: false)
    skip_after_action(*filters, raise: false)
    skip_around_action(*filters, raise: false)

    before_action :set_message

    # TODO verify signature
    def open
      publish :open

      send_data Base64.decode64("R0lGODlhAQABAPAAAAAAAAAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw=="), type: "image/gif", disposition: "inline"
    end

    def click
      user_signature = params[:signature].to_s
      url = params[:url].to_s

      # TODO sign more than just url and transition to HMAC-SHA256
      digest = "SHA1"
      signature = OpenSSL::HMAC.hexdigest(digest, AhoyEmail.secret_token, url)

      if ActiveSupport::SecurityUtils.secure_compare(user_signature, signature)
        publish :click, url: url
        redirect_to url
      else
        # TODO show link expired page with link to invalid redirect url in 2.0
        redirect_to AhoyEmail.invalid_redirect_url || main_app.root_url
      end
    end

    protected

    def publish(name, event = {})
      AhoyEmail.subscribers.each do |subscriber|
        subscriber = subscriber.new if subscriber.is_a?(Class) && !subscriber.respond_to?(name)
        if subscriber.respond_to?(name)
          # TODO move to initializer
          event[:controller] = self
          event[:token] = @token
          event[:campaign] = @campaign
          subscriber.send name, event
        end
      end
    end
  end
end
