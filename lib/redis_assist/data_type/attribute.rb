module RedisAssist
  class AttributeType < DataType::Base
    add_operation :"#{name}" do
      if attributes.is_a?(Redis::Future)
        value = attributes.value 
        self.attributes = value ? Hash[*self.class.fields.keys.zip(value).flatten] : {}
      end

      self.class.transform(:from, name, attributes[name])
    end

    add_operation :"#{name}=" do |value|
    end
  end
end
