module RedisAssist
  module Validations
    def self.included(base)
      base.extend ClassMethods
    end
    
    def validate
      errors.clear
      self.class.validations.each {|validation| validation.call(self) }
    end
    
    def valid?
      validate
      errors.empty?
    end
    
    def errors
      @errors ||= []
    end 

    def add_error(attribute, message)
      self.errors << { attribute => message }
    end
    
    module ClassMethods
      def validations
        @validations ||= []
      end
      
      def validates_presence_of(*attributes)
        validates_attributes(*attributes) do |instance, attribute, value, options|
          instance.add_error(attribute, "cant't be blank") if value.nil? || value.empty?
        end
      end
      
      def validates_format_of(*attributes)
        validates_attributes(*attributes) do |instance, attribute, value, options|
          instance.add_error(attribute, "is invalid") unless value =~ options[:with]
        end
      end
      
      def validates_attributes(*attributes, &proc)
        options = attributes.last.is_a?(::Hash) ? attributes.pop : {}
        
        validations << Proc.new do |instance|
          attributes.each do |attribute|
            proc.call(instance, attribute, instance.__send__(attribute), options)
          end
        end
      end
    end
  end
end
