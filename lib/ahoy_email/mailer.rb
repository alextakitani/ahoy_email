module AhoyEmail
  module Mailer
    extend ActiveSupport::Concern

    included do
      attr_writer :ahoy_options
      after_action :save_ahoy_options
    end

    class_methods do
      def save_history(**options)
        set_ahoy_options(options, %i(mailer user extra), message: true)
      end

      def add_utm_params(**options)
        set_ahoy_options(options, %i(utm_source utm_medium utm_term utm_content utm_campaign), utm_params: true)
      end

      def track_hits(**options)
        set_ahoy_options(options, %i(open click url_options unsubscribe_links), click: true)
      end

      private

      def set_ahoy_options(options, allowed_keywords, default_options)
        action_keywords = [:only, :except, :if, :unless]

        unknown_keywords = options.keys - allowed_keywords - action_keywords
        raise ArgumentError, "unknown keywords: #{unknown_keywords.map(&:inspect).join(", ")}" if unknown_keywords.any?

        # TODO see why not prepend_after_action
        after_action(options.slice(*action_keywords)) do
          self.ahoy_options = ahoy_options.merge(default_options).merge(options.slice(*allowed_keywords))
        end
      end
    end

    # def track(**options)
    #   self.ahoy_options = ahoy_options.merge(options)
    # end

    def ahoy_options
      @ahoy_options ||= AhoyEmail.default_options
    end

    # TODO rename
    def save_ahoy_options
      Safely.safely do
        if ahoy_options[:message] || ahoy_options[:utm_params] || ahoy_options[:open] || ahoy_options[:click]
          options = {}
          ahoy_options.each do |k, v|
            # execute options in mailer content
            options[k] = v.respond_to?(:call) ? instance_exec(&v) : v
          end
          AhoyEmail::Processor.new(self, options).perform
        end
      end
    end
  end
end
