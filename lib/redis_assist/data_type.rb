module RedisAssist
  module DataType
    module Registry
      class << self
        def persisted_attribute_types
          @persisted_attribute_types ||= {}
        end

        def register_persisted_attribute!(name, opts={})
          data_type = data_type_for(opts[:as].delete).new(name, opts={}) 

          data_type.operations.each do |method_name, operation|
            define_method(method_name) do |*args, &block|
              operation.call(*args, &block)
            end
          end
        end

        def persisted_attributes
          @persisted_attrs ||= {}
        end

        private

        def data_type_for(type_name)
          TYPES[type_name]
        end
      end
    end
  end
end
