require 'pry'
require 'redis_assist'

class Person < RedisAssist::Base
  attr_persist :first
  attr_persist :last
  attr_persist :title,            :default => "Runt"
  attr_persist :birthday,         :as => :time
  attr_persist :info,             :as => :hash
  attr_persist :toys,             :as => :list
  attr_persist :created_at,       :as => :time 
  attr_persist :deleted_at,       :as => :time 
  attr_persist :favorite_number,  :as => :integer

  attr_set        :login_dates
  attr_sorted_set :gamescores

  has_many :cats

  def validate
    add_error(:first, "you must not be named #{first}. That would mean you're ugly!") if first.eql?('RJ')
  end 
end

class Cat < RedisAssist::Base
  attr_persist  :name
  belongs_to    :person
end

class TestModel < RedisAssist::Base
  attr_persist :truthy, as: :boolean
  attr_persist :floaty, as: :float
  attr_persist :mathy,  as: :integer
  attr_persist :parsy,  as: :json
  attr_persist :timing, as: :time
end

