require 'resque-status'
require 'timeout'

class Resque::Plugins::Status::Future
    def initialize(id=nil)
        @id       = id
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
    # a Resque::Plugins::Status::Hash. Raises Timeout::Error if it
    # reaches the timeout without completing.
    #
    # If this is a future that has been chained with #then, wait for
    # the chain and then execute the callback with the return value of the
    # last element in the chain as a parameter. If the callback returns a
    # future, wait for it too.
    #
    def wait(options={})
        interval = options[:interval] || 0.2
        timeout  = options[:timeout]  || 60
        Timeout::timeout(timeout) do
            loop do
                retval = check_if_finished
                return retval if retval                
                sleep interval
            end

        end
    end
    
    protected
    
    # Check if this particular future has completed and get the return
    # value if it has.
    def check_if_finished
        if parent
            return parent_check
        else
            st = status
            return st.completed? ? st : nil
        end
    end
        
    # Check if the parent has completed. If it has, execute the callback and
    # return its return value, removing it as the parent
    def parent_check
        # If the parent has a parent, check that
        if parent.parent
            st = parent.parent_check
        else
            st = parent.status
        end
        if st and st.completed?
            # Execute the callback
            retval   = callback.(st)
            self.parent   = nil
            self.callback = nil
            # If the retval is a future, set our id and continue
            if retval.kind_of? Resque::Plugins::Status::Future
                self.id = retval.id
            # If it's something else, we've reached the bottom of the chain -
            # return it
            else
                return retval
            end
        end
        return nil
    end
    
end

# Monkeypatch RPS to include a future method that is like create() but returns
# a future
module Resque::Plugins::Status::ClassMethods
    def future(*args)
        Resque::Plugins::Status::Future.new(create *args)
    end
end
