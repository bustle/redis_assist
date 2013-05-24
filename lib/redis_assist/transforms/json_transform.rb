class JsonTransform < RedisAssist::Transform
  def self.to(val)
    JSON.generate(val) if val && !val.empty?
  end

  def self.from(val)
    val && !val.empty? ? JSON.parse(val) : nil
  end
end
