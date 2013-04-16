class BooleanTransform < RedisAssist::Transform
  def self.from(val)
    val.eql?('true') || val.eql?(true)
  end
end
