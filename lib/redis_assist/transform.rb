module RedisAssist
  def self.register_transform(transform)
    transforms[transform.key.to_sym] = transform
  end

  def self.transforms
    @transforms ||= {}
  end

  class Transform
    def self.inherited(base)
      base.extend ClassMethods
      RedisAssist.register_transform base
    end

    module ClassMethods
      def key
        StringHelper.underscore(name).gsub(/_transform$/, '').to_sym
      end

      def from(val)
        val
      end

      def to(val)
        val
      end

      def transform(direction, val)
        case direction.to_sym
        when :to    then to(val)
        when :from  then from(val)
        end
      end
    end
  end
end
