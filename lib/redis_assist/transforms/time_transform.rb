class TimeTransform < RedisAssist::Transform
  def self.to(val)
    val.to_f
  end

  def self.from(val)
    (val && !val.eql?('')) ? Time.at(val.to_f) : nil
  end
end
