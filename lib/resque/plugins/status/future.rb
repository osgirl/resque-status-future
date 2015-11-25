require 'resque-status'
require 'timeout'

class Resque::Plugins::Status::Future
    def initialize(id=nil)
        @id       = id
        @parent   = nil
        @callback = nil
    end
    
    attr_accessor :id, :parent, :callback
    
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
            if parent
                # If there's a parent, wait for it to complete first and then
                # pass its result to the callback
                st = parent.wait(options)
                retval = callback.call(st)
                # If the callback returned a future, wait for it, otherwise
                # return the callback's return value
                if retval.kind_of? Resque::Plugins::Status::Future
                    return retval.wait(options)
                else
                    return retval
                end                    
            elsif id
                loop do
                    st = Resque::Plugins::Status::Hash.get(id)
                    if st.completed?
                        return st
                    else
                        sleep interval
                    end
                end
            end
        end
    end
end

# Monkeypatch RPS to include a future method that is like create() but returns
# a future
module Resque::Plugins::Status::ClassMethods
    def future(*args)
        Resque::Plugins::Status::Future.new(create *args)
    end
end
