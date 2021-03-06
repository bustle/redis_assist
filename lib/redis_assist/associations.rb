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

        attr_persist("#{singular_name}_ids".to_sym, as: :list, default: [])

        define_method(name) do
          klass       = Module.const_get(class_name)
          records     = instance_variable_get("@_#{name}")
          return      records if records
          record_ids  = send("#{singular_name}_ids")
          records     = klass.find(record_ids)

          instance_variable_set("@_#{name}", records)
        end

        define_method("#{name}=") do |records|
          instance_variable_set("@_#{name}", records.collect(&:id))
        end

        define_method("add_#{singular_name}") do |record|
          current_records = instance_variable_get("@_#{name}")

          if record.respond_to?(StringHelper.underscore(self.class.name))
            record.send("#{StringHelper.underscore(self.class.name)}=", self)
          end

          if record.new_record?
            record.save 
          end

          if current_records
            current_records << record
          else
            current_records = [record]
          end

          send("#{singular_name}_ids") << record.id
        end
      end

      def define_belongs_to(name, opts={})
        class_name = opts[:class_name] ? opts[:class_name] : StringHelper.camelize(name)
        attr_persist("#{name}_id".to_sym, as: :integer, default: nil)

        define_method(name) do
          klass = Module.const_get(class_name)
          record = instance_variable_get("@_#{name}")
          return record if record
          record = klass.find(send("#{name}_id"))
          instance_variable_set("@_#{name}", record)
        end

        define_method("#{name}=") do |record|
          send("#{name}_id=", record.id)
          instance_variable_set("@_#{name}", record)
        end
      end
    end
  end
end
