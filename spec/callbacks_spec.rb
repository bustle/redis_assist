require 'redis_assist'

class Callsback
  include RedisAssist::Callbacks
   
  on_load            :callback, :callback2
  before_validation  :callback, :callback2
  before_create      :callback, :callback2
  before_save        :callback, :callback2
  before_update      :callback, :callback2
  after_create       :callback, :callback2
  after_save         :callback, :callback2
  after_update       :callback, :callback2
  after_delete       :callback, :callback2
  after_update       :callback, :callback2

  after_save do |record|
    record
  end

  def invoke_callbacks
    invoke_callback :on_load
    invoke_callback :before_validation
    invoke_callback :before_create
    invoke_callback :before_save
    invoke_callback :before_update
    invoke_callback :after_create
    invoke_callback :after_save
    invoke_callback :after_update
    invoke_callback :after_delete
    invoke_callback :after_update
  end

  private

  def callback
    true
  end

  def callback2
    false
  end
end

# TODO: more than just a sanity test
describe Callsback do
  let(:callsback) { Callsback.new }
  subject         { callsback }
  it              { callsback.invoke_callbacks.should }
end
