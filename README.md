# resque-status-future

This gem adds [futures](https://en.wikipedia.org/wiki/Futures_and_promises) to
the excellent [resque-status](https://github.com/quirkey/resque-status) gem.

## Why?

resque-status is great for querying the status of Resque jobs in progress, but
very often you want to wait for them to complete and then use their return
values for something.

For example, maybe you have a service that builds Docker containers on demand
and then starts them up. For this you'd want to wait for the containers to be
built before starting them, and maybe you need some data from the first job
before you know exactly how to schedule the second job.

Currently, once you've built your workflow up, you need to call the `wait`
method to process all the the jobs and get the final result.

## Chaining example

Imagine we have two resque-status jobs: one that creates Docker containers
and one that starts them.

```ruby
require 'resque-status'

class CreateContainer
    include Resque::Plugins::Status
    @queue = :create
    def perform
        container = Docker.create_container(image: options['image_name'])
        completed('container_name' => container.name)
    end
end

class StartContainer
    include Resque::Plugins::Status
    @queue = :start
    def perform
        status = Docker.start_container(name: options['container_name'])
        completed('status' => status)
    end
end
```

You can't call `StartContainer` until `CreateContainer` is completed.
Moreover, you need the container name generated during `CreateContainer` in
order to enqueue the `StartContainer` job.

This can be done with a future. A method for creating futures is added to
every resque-status class.

```ruby
require 'resque-status-future'

future = CreateContainer.future('image_name' => 'redis').then do |st|
    StartContainer.future('container_name' => st['container_name'])
end

status = future.wait
```

The callback given to `#then` can be any Ruby code and it receives the
`Resque::Plugins::Status::Hash` from the completed job before it is executed.

If the callback itself returns a future, the job will be chained and the
call to `#wait` will wait for every sequential job to complete, with the return
status of the final job being returned as the return value of `#wait` or passed
to the next item in the chain.

If the callback returns something other than a future, it will break the chain
and its value is returned by `#wait`.

## timeout and interval

`#wait` takes optional parameters:

* `timeout`: How long to wait before raising a `TimeoutError` in seconds (default: 60).
* `interval`: How often to query Redis for job status (default: 0.2).

## status

At any time you can call `future.status` to get back the current status of the
job, even if it's not completed yet. If the last job in the chain is not yet
running, this will return `nil`.

## TODO

Add a `Resque::Plugins::Status::Future.wait()` that allows for waiting for
multiple futures and gleaning all of their statuses.

## Authors

Rich Daley, 2015
