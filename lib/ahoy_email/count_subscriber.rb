module AhoyEmail
  class CountSubscriber
    def open(event)
      count_event("open", event)
    end

    def click(event)
      count_event("click", event)
    end

    def count_event(name, event)
      mailer = event[:mailer]
      url = event[:url]

      with_lock([mailer, name, url]) do
        counter = Ahoy::Counter.where(mailer: mailer, name: name, url: url).first_or_create!

        hll =
          if counter.data
            Hyperll::HyperLogLog.unserialize(counter.data)
          else
            Hyperll::HyperLogLog.new(14)
          end
        hll.offer(event[:token])

        counter.total += 1
        # cache the value for BI tools
        counter.unique = [hll.cardinality, counter.total].min
        counter.data = hll.serialize
        counter.save!
      end
    end

    def with_lock(key)
      connection = Ahoy::Counter.connection

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
