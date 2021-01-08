module Ahoy
  class MessagesController < ApplicationController
    filters = _process_action_callbacks.map(&:filter) - AhoyEmail.preserve_callbacks
    skip_before_action(*filters, raise: false)
    skip_after_action(*filters, raise: false)
    skip_around_action(*filters, raise: false)

    protect_from_forgery with: :exception

    before_action :set_vars

    def open
      check_signature

      if @verified || AhoyEmail.allow_unverified_opens
        publish :open
      end

      send_data Base64.decode64("R0lGODlhAQABAPAAAAAAAAAAACH5BAEAAAAALAAAAAABAAEAAAICRAEAOw=="), type: "image/gif", disposition: "inline"
    end

    def click
      url = (params[:u] || params[:url]).to_s

      check_signature(url: url)

      if @verified
        publish :click, url: url
        redirect_to url
      else
        render layout: false
      end
    end

    protected

    def set_vars
      if params[:id]
        @endpoint_version = 1
        @token = params[:id].to_s
        @signature = params[:signature].to_s
      else
        @endpoint_version = 2
        @token = params[:t].to_s
        @campaign_id = params[:c].to_s
        @signature = params[:s].to_s
      end
    end

    def check_signature(url: nil)
      if @endpoint_version == 2
        data = [@token, @campaign_id]
        data << url if url
        data = data.join("/")

        # TODO use HMAC-SHA256
        expected = OpenSSL::HMAC.hexdigest("SHA1", AhoyEmail.secret_token, data)
        @verified = ActiveSupport::SecurityUtils.secure_compare(@signature, expected)

        # use separate variable for additional safety against coding errors
        @campaign_verified = @verified
      elsif @signature.present?
        data = url
        expected = OpenSSL::HMAC.hexdigest("SHA1", AhoyEmail.secret_token, data)
        @verified = ActiveSupport::SecurityUtils.secure_compare(@signature, expected)
      else
        @verified = false
      end
    end

    def publish(name, data = {})
      AhoyEmail.subscribers.each do |subscriber|
        subscriber = subscriber.new if subscriber.is_a?(Class) && !subscriber.respond_to?(name)
        if subscriber.respond_to?(name)
          event = {token: @token}

          # important - only pass campaign id if verified
          event[:campaign_id] = @campaign_id if @campaign_verified

          # TODO move to initializer
          event[:controller] = self

          subscriber.send(name, event.merge(data))
        end
      end
    end
  end
end
