class JsonTransform < RedisAssist::Transform
  def self.to(val)
    JSON.generate(val) if val
  end

  def self.from(val)
    val ? JSON.parse(val) : nil
  end
end
