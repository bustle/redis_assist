module RedisAssist
  module DataType

    TYPES = []

    class Base

      attr_reader :name, :config

      class << self
        def add_operation(method_name, &block)
          operations[method_name] = block
        end

        def operations
          @operations ||= {}
        end
      end

      def initialize(name, opts={})
        @name   = name
        @config = opts
      end
    end
  end
end
