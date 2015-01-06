class IntegerTransform < RedisAssist::Transform
  def self.from(val)
    val ? val.to_i : nil
  end
end
