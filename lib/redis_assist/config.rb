module RedisAssist
  class Config
    class << self
      def redis_client
        return @redis_client if @redis_client
        redis_config      = { :host => '127.0.0.1' } 
        self.redis_client = Redis.new(redis_config) 
      end

      def redis_client=(val)
        @redis_client = val
      end
    end
  end
end
