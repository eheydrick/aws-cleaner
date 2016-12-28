require 'bundler/gem_tasks'
require 'rubocop/rake_task'
require 'rspec/core/rake_task'

desc 'Run Rubocop'
RuboCop::RakeTask.new(:rubocop) do |task|
  task.patterns = ['bin/*.rb', 'lib/**/*.rb']
end

RSpec::Core::RakeTask.new(:spec)

task default: [:rubocop, :spec]
