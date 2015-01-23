class IntegerTransform < RedisAssist::Transform
  def self.from(val)
    return nil if val.eql?('')
    Integer(val)
  rescue
    nil
  end
end
