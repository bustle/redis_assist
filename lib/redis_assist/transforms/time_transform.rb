class TimeTransform < RedisAssist::Transform
  def self.to(val)
    time = val.is_a?(String) ? Time.parse(val) : val
    time ? time.to_f : time
  end

  def self.from(val)
    (val && !val.eql?('')) ? Time.at(val.to_f) : nil
  end
end
