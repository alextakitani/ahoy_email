module AhoyEmail
  class RedisSubscriber
    attr_reader :redis

    def initialize
      @redis = Redis.new
    end

    def sent(event)
      campaign_prefix = "ahoy_email:campaigns:#{event[:campaign_id]}"
      redis.incr("#{campaign_prefix}:total_sent")
    end

    def open(event)
      campaign_prefix = "ahoy_email:campaigns:#{event[:campaign_id]}"
      redis.incr("#{campaign_prefix}:total_opens")
      redis.pfadd("#{campaign_prefix}:unique_opens", event[:token])
    end

    def click(event)
      campaign_prefix = "ahoy_email:campaigns:#{event[:campaign_id]}"
      redis.incr("#{campaign_prefix}:total_clicks")
      redis.pfadd("#{campaign_prefix}:unique_clicks", event[:token])

      url_prefix = "#{campaign_prefix}:urls:#{event[:url]}"
      redis.incr("#{url_prefix}:total_clicks")
      redis.pfadd("#{url_prefix}:unique_clicks", event[:token])
      redis.sadd("#{campaign_prefix}:urls", event[:url])
    end

    def stats(campaign_id)
      campaign_prefix = "ahoy_email:campaigns:#{campaign_id}"

      stats = {
        total_sent: redis.get("#{campaign_prefix}:total_sent").to_i
      }

      total_opens = redis.get("#{campaign_prefix}:total_opens").to_i
      if total_opens > 0
        stats[:total_opens] = total_opens
        stats[:unique_opens] = redis.pfcount("#{campaign_prefix}:unique_opens")
      end

      stats[:total_clicks] = redis.get("#{campaign_prefix}:total_clicks").to_i
      stats[:unique_clicks] = redis.pfcount("#{campaign_prefix}:unique_clicks")

      stats[:urls] = []
      redis.smembers("#{campaign_prefix}:urls").each do |url|
        url_prefix = "#{campaign_prefix}:urls:#{url}"
        stats[:urls] << {
          url: url,
          total_clicks: redis.get("#{url_prefix}:total_clicks").to_i,
          unique_clicks: redis.pfcount("#{url_prefix}:unique_clicks"),
        }
      end

      stats
    end
  end
end
