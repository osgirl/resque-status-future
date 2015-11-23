require "bundler/gem_tasks"
require "rspec/core/rake_task"
require_relative "./spec/support/examples.rb"
require "resque/tasks"

RSpec::Core::RakeTask.new(:spec)

task :default => :spec

task 'resque:setup' do
    Resque.logger = Logger.new(STDOUT)
    Resque.logger.level = Logger::INFO
end
