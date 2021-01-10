module AhoyEmail
  class HitSubscriber
    def sent(event)
      query = ["INSERT INTO ahoy_campaigns (name, total_sent) VALUES (?, 1) ON CONFLICT (name) DO UPDATE SET total_sent = ahoy_campaigns.total_sent + 1", event[:campaign]]
      Ahoy::Campaign.connection.execute(Ahoy::Campaign.send(:sanitize_sql_array, query))
    end

    def open(event)
      count_hit(event, :total_opens, :unique_opens, :open_data)
    end

    def click(event)
      campaign = count_hit(event, :total_clicks, :unique_clicks, :click_data)
      count_url(campaign, event) if campaign
    end

    private

    def count_hit(event, total_attribute, unique_attribute, data_attribute)
      # campaign only passed if verified
      return unless event[:campaign]

      campaign = nil
      with_lock([event[:campaign]], Ahoy::Campaign) do
        campaign = Ahoy::Campaign.find_by(name: event[:campaign])
        update_object(campaign, event, total_attribute, unique_attribute, data_attribute) if campaign
      end
      campaign
    end

    def count_url(campaign, event)
      url = event[:url].first(255)
      with_lock([campaign.id, url], Ahoy::Url) do
        url = campaign.urls.where(url: url).first_or_create!
        update_object(url, event, :total_clicks, :unique_clicks, :click_data)
      end
    end

    def update_object(obj, event, total_attribute, unique_attribute, data_attribute)
      data = obj.send(data_attribute)
      hll =
        if data
          Hyperll::HyperLogLog.unserialize(data)
        else
          Hyperll::HyperLogLog.new(14)
        end
      hll.offer(event[:token])

      obj.increment(total_attribute)
      obj.send("#{unique_attribute}=", [hll.cardinality, obj.send(total_attribute)].min)
      obj.send("#{data_attribute}=", hll.serialize)
      obj.save!
    end

    def with_lock(key, model)
      connection = model.connection

      # MySQL and Postgres
      if connection.advisory_locks_enabled?
        lock_id = Zlib.crc32(key.join("/"))
        lock_acquired = false

        started_at = Time.now

        begin
          with_tries(10) do
            lock_acquired = connection.get_advisory_lock(lock_id)
            if lock_acquired
              # puts "Waited for #{((Time.now - started_at) * 1000.0).round}ms"
              started_at = Time.now
              yield
              # puts "Locked for #{((Time.now - started_at) * 1000.0).round}ms"
            end
            lock_acquired
          end
        ensure
          connection.release_advisory_lock(lock_id) if lock_acquired
        end
      else
        yield
      end
    end

    def with_tries(tries)
      loop do
        success = yield
        break if success

        if tries == 0
          warn "[ahoy_email] Lock not acquired"
          break
        end

        tries -= 1
        sleep(0.01)
      end
    end
  end
end
