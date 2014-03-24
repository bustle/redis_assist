require 'pry'
module RedisAssist
  class Base


    include Callbacks
    include Validations
    include Associations


    extend RedisAssist::Finders

  
    def self.inherited(base)
      base.before_create {|record| record.send(:created_at=, Time.now.to_f) if record.respond_to?(:created_at) }
      base.before_update {|record| record.send(:updated_at=, Time.now.to_f) if record.respond_to?(:updated_at) }
      base.after_create  {|record| record.send(:new_record=, false) }
    end
 

    class << self

      def redis_persist(name, **kwargs)
        options = {
          as:       :string,
          preload:  true,
          default:  nil,
          read: proc {|record|
            if record.attributes.is_a?(Redis::Future)
              value = record.attributes.value 
              record.attributes = value ? ::Hash[*preloadable_attributes.keys.zip(value).flatten] : {}
            end

            record.attributes[name]
          },
          write: proc {|record, val|
            if record.attributes.is_a?(Redis::Future)
              value = record.attributes.value 
              record.attributes = value ? ::Hash[*preloadable_attributes.keys.zip(value).flatten] : {}
            end

            record.attributes[name] = val
          } 
        }.merge(kwargs)

        redis_computed(name, options)
      end

      def redis_computed(name, as: :string, read: nil, write: nil, preload: false, **options)
        computed_attributes[name] = options.merge(as: as, preload: preload, read: read, write: write)

        if read
          define_method(name) do |*args|
            read_attribute(name, *args, &read)
          end
        end
  
        if write
          define_method("#{name}=") do |val, *args| 
            write_attribute(name, val, *args, &write)
          end
        end
      end

      def redis_sorted_set(name)
        define_attr_type(name: name, type: RedisAssist::SortedSet)
      end

      def redis_list(name)
        define_attr_type(name: name, type: RedisAssist::List)
      end

      def redis_set(name)
        define_attr_type(name: name, type: RedisAssist::Set)
      end

      def redis_hash(name)
        define_attr_type(name: name, type: RedisAssist::Hash)
      end

      def redis_string(name)
        define_attr_type(name: name, type: RedisAssist::String)
      end



      # Get count of records
      def count
        SortedSet.zcard(index_key_for(:id))
      end
  

      def create(attrs={})
        roll = new(attrs)
        roll.save ? roll : false
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
            if computed_attributes.include?(attr)
              Hash.hset(key_for(id, :attributes), attr, transform(:to, attr, val)) 
            end
          end
        end

        record.send(:invoke_callback, :after_save)
        record.send(:invoke_callback, :after_update)
      end


      def transform(direction, attr, val)
        transformer = RedisAssist.transforms[computed_attributes[attr][:as]]

        if transformer
          transformer.transform(direction, val)
        else
          val || computed_attributes[attr][:default]
        end
      end

      def computed_attributes
        @computed_attributes ||= {}
      end

      def preloadable_attributes
        computed_attributes.select{|k,v| v[:preload].eql?(true) }
      end
  

      # def lists 
      #   persisted_attrs.select{|k,v| v[:as].eql?(:list) }
      # end
  

      # def hashes 
      #   persisted_attrs.select{|k,v| v[:as].eql?(:hash) }
      # end


      # # TODO: Attribute class
      # def persisted_attrs
      #   @persisted_attrs ||= {}
      # end

      def redis_attrs
        @redis_attrs ||= []
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
            future_fields = nil
   
            future_fields = pipe.hmget(key_for(id, :attributes), preloadable_attributes.keys)

            futures[id] = { 
              fields: future_fields, 
              exists: pipe.exists(key_for(id, :attributes))
            } 
          end
        end

        future_attrs
      end
      

      def hash_to_redis(obj)
        obj.each_with_object([]) {|kv,args| args << kv[0] << kv[1] }
      end


      private


      def define_attr_type(name: nil, type: nil)
        define_method(name) do
          inst_var = instance_variable_get("@_#{name}")

          unless inst_var
            inst_var = type.new(key: key_for(name))
            instance_variable_set("@_#{name}", inst_var)
          end

          inst_var
        end

        redis_attrs << name
      end
    end
  

    attr_accessor :attributes

    def id
      @id.to_i
    end
    
    def initialize(attrs={})
      self.attributes   = {}
  
      if attrs[:id]
        self.id = attrs[:id]
        load_attributes(attrs[:raw_attributes])
        return self if self.id 
      end
  
      self.new_record = true
  
      invoke_callback(:on_load)
  
      self.class.preloadable_attributes.keys.each do |name|
        send("#{name}=", attrs[name]) if attrs[name]
        attrs.delete(name)
      end
  
      raise "RedisAssist: #{self.class.name} does not support attributes: #{attrs.keys.join(', ')}" if attrs.length > 0
    end


    # Transform and read a standard attribute
    def read_attribute(name)
      attr_opts = self.class.computed_attributes[name]
      if attr_opts && attr_opts[:read] 
        binding.pry if name.eql? :last_login_at

        val = self.class.transform(:from, name, attr_opts[:read].call(self))
        val ? val : attr_opts[:default]
      end
    end

    # Transform and write a standard attribute value
    def write_attribute(name, val)
      attr_opts = self.class.computed_attributes[name]
      if attr_opts && attr_opts[:write]
        attr_opts[:write].call(self, self.class.transform(:to, name, val)) 
        val
      end
    end

  
    def saved?
      !!(new_record?.eql?(false) && id)
    end


    # Update fields without hitting the callbacks
    def update_columns(attrs)
      redis.multi do
        attrs.each do |attr, value|
          if self.class.preloadable_attributes.has_key?(attr)
            write_attribute(attr, value)  
            redis.hset(key_for(:attributes), attr, self.class.transform(:to, attr, value)) unless new_record?
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
          redis.del(key_for(:attributes))
          self.class.redis_attrs.each do |name|
            redis.del(key_for(name))
          end
        end
      end

      remove_from_index(:id, id)

      invoke_callback(:after_delete)

      self
    end

    def undelete
      if deleted?
        remove_from_index(:deleted_at, id)
        insert_into_index(:id, id, id)
        self.deleted_at = nil
      end
      save
    end

    def new_record?
      !!new_record
    end
  
    def redis
      self.class.redis
    end
   

    def key_for(attribute)
      self.class.key_for(id, attribute)
    end


    def inspect
      attr_list = self.class.preloadable_attributes.map{|key,val| key } * ", "
      "#<#{self.class.name} id: #{id}, #{attr_list}>"
    end


    protected 
  
  
    attr_writer   :id
    attr_accessor :new_record # :lists, :hashes, 
 

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
   
    def load_attributes(raw_attributes)
      return nil unless raw_attributes
      self.attributes   = raw_attributes[:fields]
      self.new_record = false
    end
  
    ##
    # This converts a hash into args for a redis hmset
    def hash_to_redis(obj)
      self.class.hash_to_redis(obj)
    end
  end
end
