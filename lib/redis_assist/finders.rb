module RedisAssist
  module Finders

    # Checks to see if a record exists for the given `id`
    # @param id [Integer] the record id
    # @return [true, false]
    def exists?(id)
      redis.exists(key_for(id, :attributes))      
    end
 

    # Find every saved record 
    # @return [Array] the array of models
    def all
      ids = redis.zrange(index_key_for(:id), 0, -1)
      find(ids)
    end


    # Find the first saved record
    # @note `first` uses a sorted set as an index of `ids` and finds the lowest id. 
    # @param limit [Integer] returns one or many
    # @param offset [Integer] from the beginning of the index, forward.
    # @return [Base, Array]
    def first(limit=1, offset=0)
      from    = offset
      to      = from + limit - 1
      members = redis.zrange(index_key_for(:id), from, to)

      find(limit > 1 ? members : members.first)
    end


    # Find the first saved record
    # @note `last` uses a sorted set as an index of `ids` and finds the highest id. 
    # @param limit [Integer] returns one or many
    # @param offset [Integer] from the end of the index, back
    # @return [Base, Array] 
    def last(limit=1, offset=0)
      from    = offset
      to      = from + limit - 1
      members = redis.zrange(index_key_for(:id), (to * -1) + -1, (from * -1) + -1).reverse

      find(limit > 1 ? members : members.first)
    end

    # Find a record by `id`
    # @param ids [Integer, Array<Integer>] of the record(s) to lookup.
    # @return [Base, Array] matching records
    def find(ids, opts={})
      ids.is_a?(Array) ? find_by_ids(ids, opts) : find_by_id(ids, opts)
    end


    # @deprecated Use {#find} instead
    def find_by_id(id, opts={})
      raw_attributes = load_attributes(id)
      return nil unless raw_attributes[id][:exists].value
      obj = new(id: id, raw_attributes: raw_attributes[id])
      (obj.deleted? && !opts[:deleted].eql?(true)) ? nil : obj
    end
  

    # @deprecated Use {#find} instead
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


    # Iterate over all records in batches
    # @param options [Hash] accepts options
    #   `:start` to offset from the beginning of index,
    #   `:batch_size` the size of the batch, default is 500.
    # @param &block [Proc] passes each batch of articles to the Proc.
    def find_in_batches(options={})
      start       = options[:start]      || 0
      marker      = start
      batch_size  = options[:batch_size] || 500
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

  end
end
