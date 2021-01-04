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

      # TODO lock
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
end
