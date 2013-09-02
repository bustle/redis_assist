module RedisAssist
  class Base

    include Callbacks
    include Validations
    include Associations
  
    def self.inherited(base)
      base.before_create {|record| record.send(:created_at=, Time.now.to_f) if record.respond_to?(:created_at) }
      base.before_update {|record| record.send(:updated_at=, Time.now.to_f) if record.respond_to?(:updated_at) }
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


      # Get count of records
      def count
        redis.zcard(index_key_for(:id))
      end

      def first(limit=1, offset=0)
        from    = offset
        to      = from + limit - 1
        members = redis.zrange(index_key_for(:id), from, to)

        find(limit > 1 ? members : members.first)
      end


      def last(limit=1, offset=0)
        from    = offset
        to      = from + limit - 1
        members = redis.zrange(index_key_for(:id), (to * -1) + -1, (from * -1) + -1).reverse

        find(limit > 1 ? members : members.first)
      end


      def find(ids, opts={})
        ids.is_a?(Array) ? find_by_ids(ids, opts) : find_by_id(ids, opts)
      end


      # find articles in batches
      def find_in_batches(params={})
        start       = params[:start]      || 0
        marker      = start
        batch_size  = params[:batch_size] || 500
        record_ids  = redis.zrange(index_key_for(:id), marker, marker + batch_size - 1)

        while record_ids.length > 0
          records_count   = record_ids.length
          marker          += records_count
          records         = find(record_ids)

          yield records

          break if records_count < batch_size

          record_ids = redis.zrange(index_key_for(:id), marker, marker + batch_size - 1)
        end
      end


      # Deprecated finds
      def find_by_id(id, opts={})
        raw_attributes = load_attributes(id)
        return nil unless raw_attributes[id][:exists].value
        obj = new(id: id, raw_attributes: raw_attributes[id])
        (obj.deleted? && !opts[:deleted].eql?(true)) ? nil : obj
      end
  

      def find_by_ids(ids, opts={})
        attrs = load_attributes(*ids)
        raw_attributes = attrs
        ids.each_with_object([]) do |id, instances| 
          if raw_attributes[id][:exists].value
            instance = new(id: id, raw_attributes: raw_attributes[id])
            instances << instance if instance && (!instance.deleted? || opts[:deleted].eql?(true))
          end
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
      def update(id, params={}, opts={})
        record = find(id)
        return false unless record

        record.send(:invoke_callback, :before_update)
        record.send(:invoke_callback, :before_save)

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

        record.send(:invoke_callback, :after_save)
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


      def index_key_for(index_name)
        "#{key_prefix}:index:#{index_name}"
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

            futures[id] = { 
              lists:  future_lists, 
              hashes: future_hashes, 
              fields: future_fields, 
              exists: pipe.exists(key_for(id, :attributes))
            } 
          end
        end

        future_attrs
      end
      

      def hash_to_redis(obj)
        obj.each_with_object([]) {|kv,args| args<<kv[0]<<kv[1] }
      end


      private


      def define_list(name)
        define_method(name) do
          read_list(name)
        end
  
        define_method("#{name}=") do |val|
          write_list(name, val)
        end
      end


      def define_hash(name)
        define_method(name) do
          read_hash(name)
        end
  
        define_method("#{name}=") do |val|
          write_hash(name, val)
        end
      end


      def define_attribute(name)
        define_method(name) do 
          read_attribute(name)
        end
  
        define_method("#{name}=") do |val| 
          write_attribute(name, val)
        end
      end
    end
  

    attr_accessor :attributes

    def id
      @id.to_i
    end
    
    def initialize(attrs={})
      self.attributes = {}
      self.lists      = {}
      self.hashes     = {}
  
      if attrs[:id]
        self.id = attrs[:id]
        load_attributes(attrs[:raw_attributes])
        return self if self.id 
      end
  
      self.new_record = true
  
      invoke_callback(:on_load)
  
      self.class.persisted_attrs.keys.each do |name|
        send("#{name}=", attrs[name]) if attrs[name]
        attrs.delete(name)
      end
  
      raise "RedisAssist: #{self.class.name} does not support attributes: #{attrs.keys.join(', ')}" if attrs.length > 0
    end


    # Transform and read a standard attribute
    def read_attribute(name)
      if attributes.is_a?(Redis::Future)
        value = attributes.value 
        self.attributes = value ? Hash[*self.class.fields.keys.zip(value).flatten] : {}
      end

      self.class.transform(:from, name, attributes[name])
    end

    # Transform and read a list attribute
    def read_list(name)
      opts = self.class.persisted_attrs[name]

      if !lists[name] && opts[:default]
        opts[:default]
      else
        send("#{name}=", lists[name].value) if lists[name].is_a?(Redis::Future)
        lists[name]
      end
    end

    # Transform and read a hash attribute
    def read_hash(name)
      opts = self.class.persisted_attrs[name]

      if !hashes[name] && opts[:default]
        opts[:default]
      else
        self.send("#{name}=", hashes[name].value) if hashes[name].is_a?(Redis::Future)
        hashes[name]
      end
    end


    # Transform and write a standard attribute value
    def write_attribute(name, val)
      attributes[name] = self.class.transform(:to, name, val)
    end

    # Transform and write a list value
    def write_list(name, val)
      raise "RedisAssist: tried to store a #{val.class.name} as Array" unless val.is_a?(Array)
      lists[name] = val
    end

    # Transform and write a hash attribute 
    def write_hash(name, val)
      raise "RedisAssist: tried to store a #{val.class.name} as Hash" unless val.is_a?(Hash)
      hashes[name] = val
    end
  
    def saved?
      !!(new_record?.eql?(false) && id)
    end

    # Update fields without hitting the callbacks
    def update_columns(attrs)
      redis.multi do
        attrs.each do |attr, value|
          if self.class.fields.has_key?(attr)
            write_attribute(attr, value)  
            redis.hset(key_for(:attributes), attr, self.class.transform(:to, attr, value)) unless new_record?
          end

          if self.class.lists.has_key?(attr)
            write_list(attr, value)       

            unless new_record?
              redis.del(key_for(attr))
              redis.rpush(key_for(attr), value) unless value.empty?
            end
          end

          if self.class.hashes.has_key?(attr)
            write_hash(attr, value)       

            unless new_record?
              hash_as_args = hash_to_redis(value)
              redis.hmset(key_for(attr), *hash_as_args)
            end
          end
        end
      end
    end
  
    def save
      return false unless valid? 
  
      invoke_callback(:before_update) unless new_record?
      invoke_callback(:before_create) if new_record?
      invoke_callback(:before_save)
  
      # Assing the record with the next available ID
      self.id = generate_id if new_record?

      redis.multi do
        # Add to the index
        insert_into_index(:id, id, id) if new_record? 

        # Remove soft-deleted record from index
        if deleted?
          remove_from_index(:id, id)
          insert_into_index(:deleted_at, deleted_at.to_i, id)
        end

        # build the arguments to pass to redis hmset
        # and insure the attributes are explicitely declared
        unless attributes.is_a?(Redis::Future)
          attribute_args = hash_to_redis(attributes)
          redis.hmset(key_for(:attributes), *attribute_args)
        end
  
        lists.each do |name, val|
          if val && !val.is_a?(Redis::Future) 
            redis.del(key_for(name))
            redis.rpush(key_for(name), val) unless val.empty?
          end
        end
  
        hashes.each do |name, val|
          unless val.is_a?(Redis::Future)
            hash_as_args = hash_to_redis(val)
            redis.hmset(key_for(name), *hash_as_args)
          end
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
        redis.multi do
          redis.zrem(self.class.primary_key_index_key, id)
          redis.del(key_for(:attributes))
          lists.merge(hashes).each do |name|
            redis.del(key_for(name))
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
  

    def insert_into_index(name, score, member)
      redis.zadd(self.class.index_key_for(name), score, member)
    end

    def remove_from_index(name, member)
      redis.zrem(self.class.index_key_for(name), member)
    end
  
    def generate_id
      redis.incr("#{self.class.key_prefix}:id_sequence")
    end
  
    def key_for(attribute)
      self.class.key_for(id, attribute)
    end
  
    def load_attributes(raw_attributes)
      return nil unless raw_attributes
      self.lists      = raw_attributes[:lists] 
      self.hashes     = raw_attributes[:hashes] 
      self.attributes = raw_attributes[:fields]
      self.new_record = false
    end
  
    ##
    # This converts a hash into args for a redis hmset
    def hash_to_redis(obj)
      self.class.hash_to_redis(obj)
    end
  end
end
