module AhoyEmail
  class HitSubscriber
    def open(event)
      count_hit(event, :total_opens, :unique_opens, :open_data)
    end

    def click(event)
      count_hit(event, :total_clicks, :unique_clicks, :click_data)
    end

    private

    def count_hit(event, total_attribute, unique_attribute, data_attribute)
      # campaign only passed if verified
      return unless event[:campaign_id]

      with_lock([event[:campaign_id]]) do
        campaign = Ahoy::Campaign.find_by(id: event[:campaign_id])
        return unless campaign

        data = campaign.send(data_attribute)
        hll =
          if data
            Hyperll::HyperLogLog.unserialize(data)
          else
            Hyperll::HyperLogLog.new(14)
          end
        hll.offer(event[:token])

        campaign.increment(total_attribute)
        campaign.send("#{unique_attribute}=", [hll.cardinality, campaign.send(total_attribute)].min)
        campaign.send("#{data_attribute}=", hll.serialize)
        campaign.save!
      end
    end

    def with_lock(key)
      connection = Ahoy::Campaign.connection

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
