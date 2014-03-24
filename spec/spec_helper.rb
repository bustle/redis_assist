require 'pry'
require 'redis_assist'

class Person < RedisAssist::Base
  redis_persist    :first
  redis_persist    :last
  redis_persist    :title,            :default => "Runt"
  redis_persist    :birthday,         :as => :time
  redis_persist    :created_at,       :as => :time 
  redis_persist    :deleted_at,       :as => :time 
  redis_persist    :favorite_number,  :as => :integer

  redis_hash       :info
  redis_list       :login_dates

  has_many :cats

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

