class FloatTransform < RedisAssist::Transform
  def self.from(val)
    val.to_f
  end
end
