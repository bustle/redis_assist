module RedisAssist
  module Associations
    def self.included(base)
      base.extend ClassMethods
    end

    module ClassMethods
      def has_many(name, opts={})
        define_has_many(name, opts)
      end

      def belongs_to(name, opts={})
        define_belongs_to(name, opts)
      end

      private

      def define_has_many(name, opts={})
        singular_name = StringHelper.singularize(name)
        class_name    = opts[:class_name] ? opts[:class_name] : StringHelper.camelize(singular_name)

        attr_persist("#{singular_name}_ids", as: :list, default: [])

        define_method(name) do
          klass   = Module.const_get(class_name)
          records = instance_variable_get("@_#{name}")

          return records if records

          record_ids  = send("#{singular_name}_ids")
          records     = self.class.find(record_ids)

          instance_variable_set("@_#{name}", records)
        end

        define_method("#{name}=") do |records|
          record_ids = records.collect(&:id)
          instance_variable_set("@_#{name}", records)
        end

        define_method("add_#{singular_name}") do |record|
          record.save if record.new_record?
          send(name)
          record.send("#{StringHelper.underscore(self.class.name)}_id=", self.id)
          instance_variable_get("@_#{name}") << record
          send("#{singular_name}_ids") << record.id
        end
      end

      def define_belongs_to(name, opts={})
        class_name = opts[:class_name] ? opts[:class_name] : StringHelper.camelize(name)
        attr_persist("#{name}_id", as: :integer)

        define_method(name) do
          klass = Module.const_get(class_name)
          record = instance_variable_get("@_#{name}")
          return record if record
          record = opts[:class].find(send("#{name}_id"))
          instance_variable_set("@_#{name}", record)
        end

        define_method("#{name}=") do |record|
          instance_variable_set("@_#{name}", record)
        end
      end
    end
  end
end
