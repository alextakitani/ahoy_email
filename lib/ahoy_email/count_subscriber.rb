module AhoyEmail
  class CountSubscriber
    def open(event)
      count_event("open", event)
    end

    def click(event)
      count_event("click", event)
    end

    def count_event(name, event)
      # TODO don't use message
      mailer = event[:message].mailer
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

        counter.value = hll.cardinality
        counter.data = hll.serialize
        counter.save!
      end
    end

    # TODO support other database adapters
    def with_lock(key)
      lock_id = 1 # TODO hash key
      retries = 0
      connection = Ahoy::Counter.connection
      begin
        started_at = Time.now

        loop do
          if connection.get_advisory_lock(lock_id)
            puts "Waited for #{((Time.now - started_at) * 1000.0).round}ms"
            started_at = Time.now
            yield
            puts "Locked for #{((Time.now - started_at) * 1000.0).round}ms"
            break
          else
            retries += 1
            sleep(0.01)
            raise "Lock not acquired" if retries > 10
          end
        end
      ensure
        connection.release_advisory_lock(lock_id)
      end
    end
  end
end
