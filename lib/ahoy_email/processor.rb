module AhoyEmail
  class Processor
    attr_reader :mailer, :options

    UTM_PARAMETERS = %w(utm_source utm_medium utm_term utm_content utm_campaign)

    def initialize(mailer, options)
      @mailer = mailer
      @options = options

      unknown_keywords = options.keys - AhoyEmail.default_options.keys
      raise ArgumentError, "unknown keywords: #{unknown_keywords.join(", ")}" if unknown_keywords.any?
    end

    def perform
      track_open if options[:open]
      track_links if options[:utm_params] || options[:click]
      track_message if options[:message]
      message.ahoy_campaign = campaign if options[:open] || options[:click]
    end

    protected

    def message
      mailer.message
    end

    def token
      @token ||= SecureRandom.urlsafe_base64(32).gsub(/[\-_]/, "").first(32)
    end

    def track_message
      data = {
        mailer: options[:mailer],
        extra: options[:extra],
        user: options[:user]
      }

      # TODO remove in next major version
      user = options[:user]
      if user
        data[:user_type] = user.model_name.name
        id = user.id
        data[:user_id] = id.is_a?(Integer) ? id : id.to_s
      end

      if options[:open] || options[:click]
        data[:token] = token
      end

      if options[:utm_params]
        UTM_PARAMETERS.map(&:to_sym).each do |k|
          data[k] = options[k] if options[k]
        end
      end

      data[:campaign_id] = campaign.id if campaign

      mailer.message.ahoy_data = data
    end

    def track_open
      if html_part?
        part = message.html_part || message
        raw_source = part.body.raw_source

        regex = /<\/body>/i

        signature = AhoyEmail.signature(token: token, campaign_id: campaign.try(:id))
        url =
          url_for(
            controller: "ahoy/messages",
            action: "open",
            t: token,
            c: campaign.try(:id),
            s: signature,
            format: "gif"
          )
        pixel = ActionController::Base.helpers.image_tag(url, size: "1x1", alt: "")

        # try to add before body tag
        if raw_source.match(regex)
          part.body = raw_source.gsub(regex, "#{pixel}\\0")
        else
          part.body = raw_source + pixel
        end
      end
    end

    def track_links
      if html_part?
        part = message.html_part || message

        doc = Nokogiri::HTML::DocumentFragment.parse(part.body.raw_source)
        doc.css("a[href]").each do |link|
          uri = parse_uri(link["href"])
          next unless trackable?(uri)
          # utm params first
          if options[:utm_params] && !skip_attribute?(link, "utm-params")
            params = uri.query_values(Array) || []
            UTM_PARAMETERS.each do |key|
              next if params.any? { |k, _v| k == key } || !options[key.to_sym]
              params << [key, options[key.to_sym]]
            end
            uri.query_values = params
            link["href"] = uri.to_s
          end

          if options[:click] && !skip_attribute?(link, "click")
            url = link["href"]
            signature = AhoyEmail.signature(token: token, campaign_id: campaign.try(:id), url: url)
            link["href"] =
              url_for(
                controller: "ahoy/messages",
                action: "click",
                u: url,
                t: token,
                c: campaign.try(:id),
                s: signature
              )
          end
        end

        # ampersands converted to &amp;
        # https://github.com/sparklemotion/nokogiri/issues/1127
        # not ideal, but should be equivalent in html5
        # https://stackoverflow.com/questions/15776556/whats-the-difference-between-and-amp-in-html5
        # escaping technically required before html5
        # https://stackoverflow.com/questions/3705591/do-i-encode-ampersands-in-a-href
        part.body = doc.to_s
      end
    end

    def html_part?
      (message.html_part || message).content_type =~ /html/
    end

    def skip_attribute?(link, suffix)
      attribute = "data-skip-#{suffix}"
      if link[attribute]
        # remove it
        link.remove_attribute(attribute)
        true
      elsif link["href"].to_s =~ /unsubscribe/i && !options[:unsubscribe_links]
        # try to avoid unsubscribe links
        true
      else
        false
      end
    end

    # Filter trackable URIs, i.e. absolute one with http
    def trackable?(uri)
      uri && uri.absolute? && %w(http https).include?(uri.scheme)
    end

    # Parse href attribute
    # Return uri if valid, nil otherwise
    def parse_uri(href)
      # to_s prevent to return nil from this method
      Addressable::URI.heuristic_parse(href.to_s) rescue nil
    end

    def url_for(opt)
      opt = (ActionMailer::Base.default_url_options || {})
            .merge(options[:url_options])
            .merge(opt)
      AhoyEmail::Engine.routes.url_helpers.url_for(opt)
    end

    def campaign
      @campaign ||= options[:campaign] ? self.class.fetch_campaign(options[:campaign]) : nil
    end

    class << self
      attr_accessor :mutex
    end
    self.mutex = Mutex.new

    def self.fetch_campaign(name)
      mutex.synchronize do
        campaigns[name] ||=
          begin
            Ahoy::Campaign.create!(name: name)
          rescue ActiveRecord::RecordNotUnique
            Ahoy::Campaign.find_by(name: name)
          end
      end
    end

    # no mutex needed since accessed through fetch_campaign
    def self.campaigns
      @campaigns ||= Ahoy::Campaign.all.index_by(&:name)
    end
  end
end
