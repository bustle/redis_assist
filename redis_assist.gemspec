lib = File.expand_path('../lib/', __FILE__)
$:.unshift lib unless $:.include?(lib)

require 'redis_assist/version'

Gem::Specification.new do |s|
  s.name        = "redis_assist"
  s.version     = RedisAssist::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Tyler Love"]
  s.email       = ["t@tylr.org"]
  s.homepage    = "http://github.com/endlessinc/redis_assist"
  s.summary     = %q{A framework for Redis backed ruby apps.}
  s.description = %q{A framework for Redis backed ruby apps.}

  s.rubyforge_project = "redis_assist"

  s.add_dependency('redis')

  s.add_development_dependency 'bundler',   '~> 1.7.3'
  s.add_development_dependency 'rake',      '~> 10.1.1'
  s.add_development_dependency 'yard',      '~> 0.8.7.3'
  s.add_development_dependency 'rspec',     '~> 2.14.1'
  s.add_development_dependency 'pry',       '~> 0.9.12.6'

  s.files = Dir.glob('lib/**/*.rb') 
end
