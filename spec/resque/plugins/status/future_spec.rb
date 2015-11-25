require 'spec_helper'

describe Resque::Plugins::Status::Future do
    before(:all) do
        # Sanity check environment
        begin
            Resque.redis.ping # check redis is up
            n_workers = Resque.redis.scard('workers')
            if !n_workers || n_workers < 3
                raise "Workers not running. Try starting them with:\n  COUNT=3 QUEUE=* rake resque:workers"
            end
        rescue Redis::CannotConnectError
            raise "Can't ping Redis. Try starting one with:\n  docker run -p 6379:6379 -d redis"
        end
    end
    
    describe '#then' do
        it 'returns a new future' do
            f1 = Example.future(arg1: "hello")
            f2 = f1.then { true }
            expect(f2).to be_a(Resque::Plugins::Status::Future)
            expect(f1).not_to be(f2)
        end
        it "executes block with parent's return value when waited" do
            f = Example.future(arg1: "hello").then {|st| "FOUND: #{st['example']}" }
            expect(f.wait).to eq("FOUND: hellohello")
        end
        it 'allows chaining of futures' do
            f = Example.future(arg1: "hello").then do |st|
                Example.future(arg1: "#{st['example']} world ")
            end.then do |st|
                "Finally: #{st['example']}"
            end
            expect(f.wait).to eq("Finally: hellohello world hellohello world ")
        end
    end

    describe '#wait' do
        it 'returns the values when job completes' do
            status = Example.future(arg1: "hello").wait
            expect(status).to be_a(Resque::Plugins::Status::Hash)
            expect(status['example']).to eq("hellohello")
        end
        it 'times out if job fails to complete' do
            expect { BrokenExample.future(arg1: "hello").wait(timeout: 2) }.to raise_error(TimeoutError)
        end
        it 'waits on multiple jobs even if they complete in the wrong order' do
            f1 = SlowExample.future(arg1: "hello")
            f2 = Example.future(arg1: "world")
            s1 = f1.wait
            s2 = f2.wait
            expect(s1['example']).to eq("hellohello")
            expect(s2['example']).to eq("worldworld")
            expect(s1['finish_time']).to be > s2['finish_time']
        end
    end

    describe 'Monkeypatch Resque::Plugins::Status' do
        it 'adds a future method to Resque::Plugins::Status' do
            expect(Example).to respond_to(:future)
        end
        
        it 'returns a Resque::Plugins::Status::Future when called' do
            expect(Example.future(arg1: "hello")).to be_a(Resque::Plugins::Status::Future)
        end
        
        it 'starts the job when called' do
            expect(Example).to receive(:create).with(arg1: "hello")
            Example.future(arg1: "hello")
        end
    end

end
