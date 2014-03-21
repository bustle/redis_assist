module RedisAssist
  class DataType
    class << self
      def commands(commands=nil)
        return @commands unless commands

        commands.each do |command|
          define_method(command) do |*args|
            execute(command, key, *args)
          end

          define_singleton_method(command) do |*args|
            execute(command, *args)
          end
        end

        @commands = commands
      end

      def client
        RedisAssist::Config.redis_client
      end
    end

    attr_accessor :key

    def initialize(key: key )
      raise "RedisAssist: you must provide a key" unless key 
      self.key      = key
    end

    def client
      self.class.client
    end

    def execute(command, *args)
      client.send(command, *args)
    end
  end


  class SortedSet < DataType
    commands %w(
      zadd
      zcard
      zcount
      zincrby
      zrange
      zrangebyscore
      zrank
      zrem
      zremrangebyrank
      zrevrange
      zremrangebyscore
      zrevrank
      zscore
      zscan
      zinterstore
      zunionstore
    )
  end

  class Set < DataType
    commands %w(
      sadd
      scard 
      sdiff
      skey
      sinter
      sismember
      smembers
      smove
      spop
      srandmember
      srem
      sunion
      sscan
      sdiffstore
      sinterstore
      sunionstore
    )
  end

  class List < DataType
    commands %w(
      blpop
      brpop
      brpoplpush
      lindex
      linsert
      llen
      lpop
      lpush
      lpushx
      lrange
      lrem
      lset
      ltrim
      rpop
      rpoplpush
      rpush
      rpushx
    )
  end

  class Hash < DataType
    commands %w(
      hdel
      hexists
      hget
      hgetall
      hincrby
      hincrbyfloat
      hkeys
      hlen
      hmget
      hmset
      hset
      hsetnx
      hvals
      hscan
    )
  end

  class String < DataType
    commands %w(
      append
      bitcount
      bitpos
      decr
      decrby
      get
      getbit
      getrange
      getset
      incr
      incrby
      incrybyfloat
      mget
      mset
      msetnx
      psetex
      set
      setbit
      setex
      setnx
      setrange
      strlen
    )
  end
end

