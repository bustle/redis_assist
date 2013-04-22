require 'redis_assist'

class FakePerson
  include RedisAssist::Validations

  attr_accessor :name
  attr_accessor :email

  validates_format_of :name, with: /^[a-z]+$/
  validates_presence_of :email
end

describe FakePerson do
  let(:person)  { FakePerson.new }
  let(:name)    { 'Tyler Love' } 
  let(:email)   { 'redis_assist@tylr.org' } 
  subject       { person }

  before do
    person.name   = name
    person.email  = email
  end

  context "valid data" do
    its(:valid?) { should }
  end

  context "invalid format" do
    before do 
      subject.name = 'Tyler Love 2'
      subject.validate
    end


    its(:valid?)  { should_not }
    its(:errors)  { subject.length.should > 0 } 
  end

  context "invalid presence" do
    before do 
      subject.email = nil
      subject.validate
    end

    its(:valid?)  { should_not }
    its(:errors)  { subject.length.should > 0 } 
  end
end
