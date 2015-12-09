require 'resque-status'
require 'timeout' # for the exception

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
    # a Resque::Plugins::Status::Hash. Raises TimeoutError if it
    # reaches the timeout without completing.
    #
    # If this is a future that has been chained with #then, wait for
    # the chain and then execute the callback with the return value of the
    # last element in the chain as a parameter. If the callback returns a
    # future, wait for it too.
    #
    def wait(options={})
        self.class.wait(self, options).first
    end
    
    # Wait for multiple futures at the same time. The status are returned as
    # an array, in the same order as the futures were passed in. Options are
    # the same as for #wait.
    def self.wait(*futures)
        # Pop options off the end if they're provided
        options = futures.last.kind_of?(Hash) ? futures.pop : {}
        
        interval = options[:interval] || 0.2
        timeout  = options[:timeout]  || 60       
        returns  = {}
        start_time = Time.now
        unfinished = futures
        loop do
            unfinished.each do |f|
                if retval = f.send(:check_if_finished)
                    returns[f] = retval
                end
            end
            unfinished = futures.reject {|f| returns.has_key? f}
            if unfinished.empty?
                return futures.map {|f| returns[f]}
            end
            if (Time.now - start_time) > timeout
                raise Timeout::Error
            end
            sleep interval
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
