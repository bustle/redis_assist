$LOAD_PATH << File.dirname(__FILE__) unless $LOAD_PATH.include?(File.dirname(__FILE__))

require 'time'
require 'redis'
require 'json'
require 'redis_assist/config'
require 'redis_assist/transform'
require 'redis_assist/callbacks'
require 'redis_assist/validations'
require 'redis_assist/associations'
require 'redis_assist/base'

# == Setup & Configuration
# RedisAssist depends on the redis-rb gem to communicate with redis.
# To configure your redis connection simply pass `RedisAssist` a `Redis` client instance.
#   RedisAssist::Config.redis_client = Redis.new(redis_config)
module RedisAssist
  module StringHelper
    def self.underscore(str)
      str.to_s.gsub(/::/, '/').
        gsub(/([A-Z]+)([A-Z][a-z])/,'\1_\2').
        gsub(/([a-z\d])([A-Z])/,'\1_\2').
        tr("-", "_").
        downcase
    end

    def self.camelize(str)
      str.to_s.split('_').map{|e| e.capitalize}.join
    end

    # TODO: Would love to integrate a special-cases singulizer/pluralizer without adding dependencies.
    def self.singularize(str)
      str.to_s.gsub(/s$/, '')
    end

    def self.pluralize(str)
      "#{str}s"
    end
  end
end

# require all transforms
Dir["#{File.dirname(__FILE__)}/redis_assist/transforms/*.rb"].each{|file| require file }
