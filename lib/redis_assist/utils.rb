module RedisAssist
  module Utils
    class << self

      def rename_attribute!(options={})
        raise "model option must be provided" unless klass = options[:model]
        raise "from option must be provided"  unless from  = options[:from]
        raise "to option must be provided"    unless to    = options[:to]

        klass.find_in_batches do |batch|
          batch.each do |record|
            client        = record.redis
            attr_key      = record.key_for(:attributes)
            value         = client.hget(attr_key, from)

            if value 
              client.multi do |multi|
                multi.hset(attr_key, to, value)
                multi.hdel(attr_key, from)
              end
            end
          end
        end 
      end

    end
  end
end
