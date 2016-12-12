require 'resque-status-future'

class Example

  @queue = :example
  include Resque::Plugins::Status
  def perform
    arg1 = options['arg1']
    completed example: arg1 + arg1, finish_time: Time.now
  end

end

class SlowExample

  @queue = :slowexample
  include Resque::Plugins::Status
  def perform
    arg1 = options['arg1']
    sleep 3
    completed example: arg1 + arg1, finish_time: Time.now
  end

end

class BrokenExample

  @queue = :brokenexample
  include Resque::Plugins::Status
  def perform
    raise "I'm blowing up"
  end

end

class NonTakenExample

  @queue = :foobar
  include Resque::Plugins::Status
  def perform
    arg1 = options['arg1']
    completed example: arg1 + arg1, finish_time: Time.now
  end

end
