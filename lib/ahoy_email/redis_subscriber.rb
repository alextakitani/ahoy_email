module AhoyEmail
  class RedisSubscriber
    attr_reader :redis

    def initialize
      @redis = Redis.new
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

      url_prefix = "ahoy_email:campaigns:#{event[:campaign_id]}:urls:#{event[:url]}"
      redis.incr("#{url_prefix}:total_clicks")
      redis.pfadd("#{url_prefix}:unique_clicks", event[:token])
      redis.sadd("ahoy_email:campaigns:#{event[:campaign_id]}:urls", event[:url])
    end

    def stats(campaign_id)
      campaign_prefix = "ahoy_email:campaigns:#{campaign_id}"

      stats = {}

      # TODO total sent

      total_opens = redis.get("#{campaign_prefix}:total_opens").to_i
      if total_opens > 0
        stats[:total_opens] = total_opens
        stats[:unique_opens] = redis.pfcount("#{campaign_prefix}:unique_opens")
      end

      stats[:total_clicks] = redis.get("#{campaign_prefix}:total_clicks").to_i
      stats[:unique_clicks] = redis.pfcount("#{campaign_prefix}:unique_clicks")

      stats[:urls] = []
      redis.smembers("ahoy_email:campaigns:#{campaign_id}:urls").each do |url|
        url_prefix = "ahoy_email:campaigns:#{campaign_id}:urls:#{url}"
        stats[:urls] << {
          total_clicks: redis.get("#{url_prefix}:total_clicks").to_i,
          unique_clicks: redis.pfcount("#{url_prefix}:unique_clicks"),
        }
      end

      stats
    end
  end
end
