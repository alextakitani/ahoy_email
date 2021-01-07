module Ahoy
  class MessagesController < ApplicationController
    filters = _process_action_callbacks.map(&:filter) - AhoyEmail.preserve_callbacks
    skip_before_action(*filters, raise: false)
    skip_after_action(*filters, raise: false)
    skip_around_action(*filters, raise: false)

    def open
      data = {}
      verified = signature_verified?
      if !verified && AhoyEmail.allow_unverified_opens
        data[:unverified] = true
        verified = true
      end

      if verified
        publish :open, data
      end

      send_data Base64.decode64("R0lGODlhAQABAPAAAAAAAAAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw=="), type: "image/gif", disposition: "inline"
    end

    def click
      url = (params[:u] || params[:url]).to_s

      if signature_verified?(url: url)
        publish :click, url: url
        redirect_to url
      else
        render layout: false
      end
    end

    protected

    def signature_verified?(url: nil)
      if params[:signature]
        @token = params[:id]
        user_signature = params[:signature]
        data = url
        signature = OpenSSL::HMAC.hexdigest("SHA1", AhoyEmail.secret_token, data)
        ActiveSupport::SecurityUtils.secure_compare(user_signature, signature)
      else
        @token = params[:t].to_s
        @campaign = params[:c].to_s
        user_signature = params[:s].to_s
        data = [@token, @campaign]
        data << url if url
        data = data.join("/")

        # TODO use HMAC-SHA256
        signature = OpenSSL::HMAC.hexdigest("SHA1", AhoyEmail.secret_token, data)
        ActiveSupport::SecurityUtils.secure_compare(user_signature, signature)
      end
    end

    def publish(name, data = {})
      AhoyEmail.subscribers.each do |subscriber|
        subscriber = subscriber.new if subscriber.is_a?(Class) && !subscriber.respond_to?(name)
        if subscriber.respond_to?(name)
          event = {}
          event[:token] = @token

          # important - only pass campaign if verified
          event[:campaign] = @campaign if @verified

          # TODO move to initializer
          event[:controller] = self

          subscriber.send(name, event.merge(data))
        end
      end
    end
  end
end
