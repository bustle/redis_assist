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
  s.summary     = %q{Persistant object oriented programming with redis}
  s.description = %q{Redis persistant object oriented programming}

  s.rubyforge_project         = "redis_assist"

  s.add_dependency('redis', "~> 3.0.4")
  s.add_development_dependency 'bundler', '~> 1.3.5'
  s.add_development_dependency 'rake', '~> 10.1.0'
  s.add_development_dependency 'yard', '~> 0.8.6.1'
  s.add_development_dependency 'rspec', '~> 2.3'
  s.add_development_dependency 'pry'

  s.files = Dir.glob('lib/**/*.rb') 
end
