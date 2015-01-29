class FloatTransform < RedisAssist::Transform
  def self.from(val)
    return nil if val.eql?('')
    Float(val)
  rescue
    nil
  end
end
