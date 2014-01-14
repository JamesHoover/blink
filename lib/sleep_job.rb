require 'resque'

class SleepJob
  include Resque::Plugins::Status

  def perform
    total = options.has_key?('length') ? options['length'].to_i : 1000
    num = 0
    while num < total
      at(num, total, "At #{num} of #{total}")
      sleep(0.1)
      num += 1
    end
    completed
  end

end
