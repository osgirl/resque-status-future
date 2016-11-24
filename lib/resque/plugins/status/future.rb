require 'resque-status'
require 'timeout' # for the exception

class Resque::Plugins::Status::Future

  def initialize(id = nil)
    @id = id
    @parent   = nil
    @callback = nil
  end

  attr_accessor :id, :parent, :callback

  # Get the current status of this job as a Resque::Plugins::Status::Hash.
  # Returns nil if the job hasn't started yet or this is a non-job future.
  def status
    id ? Resque::Plugins::Status::Hash.get(id) : nil
  end

  # Create a future for the given callback. If you #wait on the new future,
  # it will wait for the parent future to complete, then pass its status
  # to the provided block.
  #
  # If the provided block returns a future, that future will be waited for
  # after the callback completes.
  def then(&block)
    f = Resque::Plugins::Status::Future.new
    f.parent   = self
    f.callback = block
    f
  end

  # Wait for the operation to complete and return its result as
  # a Resque::Plugins::Status::Hash. Raises TimeoutError if it
  # reaches the timeout without completing.
  #
  # If this is a future that has been chained with #then, wait for
  # the chain and then execute the callback with the return value of the
  # last element in the chain as a parameter. If the callback returns a
  # future, wait for it too.
  #
  def wait(options = {})
    self.class.wait(self, options).first
  end

  # Wait for multiple futures at the same time. The status are returned as
  # an array, in the same order as the futures were passed in. Options are
  # the same as for #wait.
  def self.wait(*futures)
    # Pop options off the end if they're provided
    options = futures.last.is_a?(Hash) ? futures.pop : {}

    interval = options[:interval] || 0.2
    timeout  = options[:timeout]  || 60
    returns  = {}
    start_time = Time.now
    unfinished = futures
    loop do
      unfinished.each do |f|
        finished, retval = f.send(:check_if_finished)
        returns[f] = retval if finished
      end
      unfinished = futures.reject {|f| returns.key? f}
      return futures.map {|f| returns[f]} if unfinished.empty?
      raise Timeout::Error if (Time.now - start_time) > timeout
      sleep interval
    end
  end

protected

  # Check if this particular future has completed and get the return
  # value if it has. Returns two values (finished, value) in case value
  # is false
  def check_if_finished
    return parent_check if parent

    st = status
    raise st['message'] if st.failed?

    return [true, st] if st.completed?

    [false, nil]
  end

  # Check if the parent has completed. If it has, execute the callback and
  # return its return value, removing it as the parent
  def parent_check
    # If the parent has a parent, check that
    if parent.parent
      _, st = parent.parent_check
    else
      st = parent.status
    end

    raise st['message'] if st && st.failed?

    if st && st.completed?
      # Execute the callback
      retval = callback.call(st)
      self.parent   = nil
      self.callback = nil
      # If the retval is not a future, we've reached the bottom of the chain - return it
      return [true, retval] unless retval.is_a? Resque::Plugins::Status::Future
      # If the retval is not a future, set our id and continue
      self.id = retval.id
    end
    [false, nil]
  end

end

# Monkeypatch RPS to include a future method that is like create() but returns
# a future
module Resque::Plugins::Status::ClassMethods
  def future(*args)
    Resque::Plugins::Status::Future.new(create(*args))
  end
end
