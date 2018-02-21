Gem::Specification.new do |s|
  s.name        = 'aws-cleaner'
  s.version     = '2.2.0'
  s.summary     = 'AWS Cleaner cleans up after EC2 instances are terminated'
  s.description = s.summary
  s.authors     = ['Eric Heydrick']
  s.email       = 'eheydrick@gmail.com'
  s.executables = ['aws_cleaner.rb']
  s.files       = Dir.glob("{bin,lib}/**/*.rb")
  s.homepage    = 'https://github.com/eheydrick/aws-cleaner'
  s.license     = 'MIT'

  s.add_development_dependency 'bundler', '~> 1.12'
  s.add_development_dependency 'rake', '~> 12.0'
  s.add_development_dependency 'rspec', '~> 3.5'
  s.add_development_dependency 'rubocop', '~> 0.52.1'

  s.add_runtime_dependency 'aws-sdk-core', '~> 2.0'
  s.add_runtime_dependency 'chef-api', '~> 0.5'
  s.add_runtime_dependency 'hipchat', '~> 1.5'
  s.add_runtime_dependency 'rest-client', '~> 2'
  s.add_runtime_dependency 'slack-poster', '~> 2.2'
  s.add_runtime_dependency 'trollop', '~> 2.1'
end
