class IntegerTransform < RedisAssist::Transform
  def self.from(val)
    val.to_i
  end
end
