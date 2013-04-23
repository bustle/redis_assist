module RedisAssist
  class Base

    include Callbacks
    include Validations
    include Associations
  
    def self.inherited(base)
      base.before_create {|record| record.send(:created_at=, Time.now.to_f) if record.respond_to?(:created_at) }
      base.before_update {|record| record.send(:updated_at=, Time.now.to_f) if record.respond_to?(:updated_at) }
      base.after_delete  {|record| record.send(:deleted_at=, Time.now.to_f) if record.respond_to?(:deleted_at) }
      base.after_create  {|record| record.send(:new_record=, false) }
    end
 
    class << self

      def attr_persist(name, opts={})
        persisted_attrs[name] = opts

        if opts[:as].eql?(:list)
          define_list(name)
        elsif opts[:as].eql?(:hash)
          define_hash(name)
        else
          define_attribute(name)
        end
      end

      def find(ids, opts={})
        ids.is_a?(Array) ? find_by_ids(ids, opts) : find_by_id(ids, opts)
      end
  
      # Deprecated finds
      def find_by_id(id, opts={})
        raw_attributes = load_attributes(id)
        return nil unless raw_attributes[id]
        obj = new(id: id, raw_attributes: raw_attributes[id])
        (obj.deleted? && !opts[:deleted].eql?(true)) ? nil : obj
      end
  
      def find_by_ids(ids, opts={})
        attrs = load_attributes(*ids)
        raw_attributes = attrs
        ids.each_with_object([]) do |id, instances| 
          instance = new(id: id, raw_attributes: raw_attributes[id]) unless raw_attributes[id].nil?
          instances << instance if instance && (!instance.deleted? || opts[:deleted].eql?(true))
        end
      end
  
      def create(attrs={})
        roll = new(attrs)
        roll.save ? roll : false
      end

      def exists?(id)
        redis.exists(key_for(id, :attributes))      
      end

      # TODO: needs a refactor. Should this be an interface for skipping validations?
      # Should we optimize and skip the find? Support an array of ids?
      def update(id, params={})
        record = find(id)
        return false unless record

        redis.multi do
          params.each do |attr, val|
            if persisted_attrs.include?(attr)
              if fields.keys.include? attr
                transform(:to, attr, val)
                redis.hset(key_for(id, :attributes), attr, transform(:to, attr, val)) 
              end

              if lists.keys.include? attr
                redis.del(key_for(id, attr)) 
                redis.rpush(key_for(id, attr), val) unless val.empty?
              end

              if hashes.keys.include? attr
                redis.del(key_for(id, attr))
                redis.hmset(key_for(id, attr), *hash_to_redis(val))
              end
            end
          end
        end

        record.send(:invoke_callback, :after_update)
      end

      def transform(direction, attr, val)
        transformer = RedisAssist.transforms[persisted_attrs[attr][:as]]

        if transformer
          transformer.transform(direction, val)
        else
          val || persisted_attrs[attr][:default]
        end
      end

      def fields
        persisted_attrs.select{|k,v| !(v[:as].eql?(:list) || v[:as].eql?(:hash)) }
      end
  
      def lists 
        persisted_attrs.select{|k,v| v[:as].eql?(:list) }
      end
  
      def hashes 
        persisted_attrs.select{|k,v| v[:as].eql?(:hash) }
      end

      # TODO: Attribute class
      def persisted_attrs
        @persisted_attrs ||= {}
      end

      def key_for(id, attribute)
        "#{key_prefix}:#{id}:#{attribute}"
      end
  
      def key_prefix(val=nil)
        return self.key_prefix = val if val
        return @key_prefix if @key_prefix
        return self.key_prefix = StringHelper.underscore(name)
      end
  
      def key_prefix=(val)
        @key_prefix = val
      end
   
      def redis
        RedisAssist::Config.redis_client
      end
  
      def load_attributes(*ids)
        future_attrs  = {}
        attrs         = {}

        # Load all the futures into an organized Hash
        redis.pipelined do |pipe|
          ids.each_with_object(future_attrs) do |id, futures|
            future_lists  = {}
            future_hashes = {}
            future_fields = nil
  
            lists.each do |name, opts|
              future_lists[name]  = pipe.lrange(key_for(id, name), 0, -1)
            end
  
            hashes.each do |name, opts|
              future_hashes[name] = pipe.hgetall(key_for(id, name))
            end
  
            future_fields = pipe.hmget(key_for(id, :attributes), fields.keys)

            futures[id] = { lists: future_lists, hashes: future_hashes, fields: future_fields } 
          end
        end

        # Remove the empty futures
        future_attrs = ids.each_with_object({}) do |id, obj|
           obj[id] = future_attrs[id] unless future_attrs[id][:fields].value.select{|v| !v.nil? }.empty?
        end

        # Map futures to attributes
        future_attrs.each_with_object(attrs) do |kv, obj|
          lists       = kv[1][:lists].each_with_object({}){|kv,obj| obj[kv[0]] = kv[1].value unless kv[1].value.nil? }
          hashes      = kv[1][:hashes].each_with_object({}){|kv,obj| obj[kv[0]] = kv[1].value unless kv[1].value.nil?}
          fields      = Hash[*self.fields.keys.zip(kv[1][:fields].value).flatten] 
          obj[kv[0]]  = { lists: lists, hashes: hashes, fields: fields }
        end

        attrs
      end
      
      def hash_to_redis(obj)
        obj.each_with_object([]) {|kv,args| args<<kv[0]<<kv[1] }
      end

      private

      def define_list(name)
        define_method(name) do
          opts = self.class.persisted_attrs[name]
          self.send("#{name}=", opts[:default]) if !lists[name] && opts[:default]
          lists[name]
        end
  
        define_method("#{name}=") do |val|
          raise "RedisAssist: tried to store a #{val.class.name} as Array" unless val.is_a?(Array)
          lists[name] = val
        end
      end

      def define_hash(name)
        define_method(name) do
          opts = self.class.persisted_attrs[name]
          self.send("#{name}=", opts[:default]) if !hashes[name] && opts[:default]
          hashes[name]
        end
  
        define_method("#{name}=") do |val|
          raise "RedisAssist: tried to store a #{val.class.name} as Hash" unless val.is_a?(Hash)
          hashes[name] = val
        end
      end

      def define_attribute(name)
        define_method(name) do 
          self.class.transform(:from, name, attributes[name])
        end
  
        define_method("#{name}=") do |val| 
          attributes[name] = self.class.transform(:to, name, val)
        end
      end
    end
  
    attr_accessor :attributes
    attr_reader :id
  
    def initialize(attrs={})
      self.attributes = {}
      self.lists      = {}
      self.hashes     = {}
  
      if attrs[:id]
        self.id = attrs[:id]
        load_attributes(attrs[:raw_attributes])
      end

      return self if id 
  
      self.new_record = true
  
      invoke_callback(:on_load)
  
      self.class.persisted_attrs.keys.each do |name|
        send("#{name}=", attrs[name]) if attrs[name]
        attrs.delete(name)
      end
  
      raise "RedisAssist: #{self.class.name} does not support attributes: #{attrs.keys.join(', ')}" if attrs.length > 0
    end
  
    def saved?
      !!(new_record?.eql?(false) && id)
    end
  
    def save
      return false unless valid? 
  
      invoke_callback(:before_update) unless new_record?
      invoke_callback(:before_create) if new_record?
      invoke_callback(:before_save)
  
      # Assing the record with the next available ID
      self.id = generate_id if new_record?

      redis.multi do
        # build the arguments to pass to redis hmset
        # and insure the attributes are explicitely declared
        attribute_args = hash_to_redis(attributes)
 
        redis.hmset(key_for(:attributes), *attribute_args)
  
        lists.each do |name, val|
          redis.del(key_for(name))
          redis.rpush(key_for(name), val) if val && !val.empty?
        end
  
        hashes.each do |name, val|
          hash_as_args = hash_to_redis(val)
          redis.hmset(key_for(name), *hash_as_args)
        end
      end

      invoke_callback(:after_save)
      invoke_callback(:after_update) unless new_record?
      invoke_callback(:after_create) if new_record?
  
      self
    end

    def save!
      raise "RedisAssist: save! failed with errors" unless save
      self
    end
  
    def valid?
      invoke_callback(:before_validation)
      super
    end
  
    # TODO: should this be a redis-assist feature?
    def deleted?
      return false unless respond_to?(:deleted_at)
      deleted_at && deleted_at.is_a?(Time)
    end
  
    def delete
      if respond_to?(:deleted_at)
        self.deleted_at = Time.now.to_f if respond_to?(:deleted_at)
        save
      else
        redis.pipelined do |pipe|
          pipe.del(key_for(:attributes))
          lists.merge(hashes).each do |name|
            pipe.del(key_for(name))
          end
        end
      end

      invoke_callback(:after_delete)
      self
    end
  
    def new_record?
      !!new_record
    end
  
    def redis
      self.class.redis
    end
 
  

    protected 
  
  
    attr_writer   :id
    attr_accessor :lists, :hashes, :new_record
 

    private
  
  
    def generate_id
      redis.incr("#{self.class.key_prefix}:id_sequence")
    end
  
    def key_for(attribute)
      self.class.key_for(id, attribute)
    end
  
    def load_attributes(raw_attributes)
      return nil unless raw_attributes
      load_response   = self.class.load_attributes(id)
      self.lists      = load_response[id][:lists] 
      self.hashes     = load_response[id][:hashes] 
      self.attributes = load_response[id][:fields]
      self.new_record = false
    end
  
    ##
    # This converts a hash into args for a redis hmset
    def hash_to_redis(obj)
      self.class.hash_to_redis(obj)
    end
  end
end
