require 'pry'
require 'redis_assist'

class Person < RedisAssist::Base
  redis_persist :first
  redis_persist :last
  redis_persist :title,            :default => "Runt"
  redis_persist :birthday,         :as => :time
  redis_persist :created_at,       :as => :time 
  redis_persist :deleted_at,       :as => :time 
  redis_persist :favorite_number,  :as => :integer

  redis_hash        :info
  redis_list        :login_log
  redis_sorted_set  :user_events

  redis_computed :last_login_at, 
    as:     :time,
    read:   proc{|record|       record.login_log.lrange(0, 0).first },
    write:  proc{|record, val|  record.login_log.lpush(val) }

  redis_computed :latest_event,
    read:   proc{|record|       record.latest_event.zrange(-1,-1).first },
    write:  proc{|record, val|  record.latest_event.zadd(Time.now.to_i, val) }

  has_many :cats

  def log_login!
    self.last_login_at = Time.now.to_s
  end

  def validate
    add_error(:first, "you must not be named #{first}. That would mean you're ugly!") if first.eql?('RJ')
  end 
end

class Cat < RedisAssist::Base
  redis_persist   :name
  belongs_to      :person
end

class TestModel < RedisAssist::Base
  redis_persist :truthy, as: :boolean
  redis_persist :floaty, as: :float
  redis_persist :mathy,  as: :integer
  redis_persist :parsy,  as: :json
  redis_persist :timing, as: :time
end

