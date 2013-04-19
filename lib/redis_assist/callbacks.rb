module RedisAssist
  module Callbacks

    def self.included(base)
      base.extend ClassMethods
      base.define_callbacks
    end
    
    def invoke_callback(callback_type)
      receivers = self.class.callbacks[callback_type] || []
      receivers.each do |callback_proc|
        callback_proc.call(self) 
      end
    end

    module ClassMethods
      CALLBACK_TYPES = [
        :on_load,
        :before_validation,
        :before_create,
        :before_save,
        :before_update,
        :after_create,
        :after_save,
        :after_update,
        :after_delete,
        :after_update
      ]

      def callbacks
        @callbacks ||= {}
      end

      def define_callbacks
        CALLBACK_TYPES.each do |callback_type|
          define_singleton_method(callback_type) do |*callback_methods, &block|
            add_callback(callback_type) do |instance|
              callback_methods.each do |callback_method| 
                instance.send callback_method
              end

              block.call(instance) if block
            end
          end
        end
      end

    private

      def add_callback(callback_type, &block)
        callback_proc = Proc.new do |instance|
          block.call(instance)
        end

        (callbacks[callback_type] ||= []) << callback_proc 
      end
    end
  end
end
