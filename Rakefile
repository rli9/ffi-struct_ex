require 'rubygems'
require 'bundler/setup'
require "bundler/gem_tasks"
require 'rspec/core/rake_task'

RSpec::Core::RakeTask.new(:spec) do |t|
  t.ruby_opts = "-I\"#{['lib', 'spec'].join(File::PATH_SEPARATOR)}\""
end