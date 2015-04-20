module RedisAssist
  class Config
    class << self
      def redis_client
        return @redis_client if @redis_client
        self.redis_client = Redis.respond_to?(:current) ? Redis.current : Redis.new
      end

      def redis_client=(val)
        @redis_client = val
      end
    end
  end
end
