require 'resque-status'
require 'timeout'

class Resque::Plugins::Status::Future
    def initialize(id)
        @id = id
    end
        
    # Wait for the operation to complete and return its result as
    # a Resque::Plugins::Status::Hash. Raises Timeout::Error if it
    # reaches the timeout without completing.
    def wait(options={})
        interval = options[:interval] || 0.2
        timeout  = options[:timeout]  || 60
        Timeout::timeout(timeout) do
            loop do
                st = Resque::Plugins::Status::Hash.get(@id)
                if st.completed?
                    return st
                else
                    sleep interval
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
