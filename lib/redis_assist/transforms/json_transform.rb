class JsonTransform < RedisAssist::Transform
  def self.to(val)
    JSON.generate(val)
  end

  def self.from(val)
    JSON.parse(val)
  end
end
