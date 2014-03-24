require 'redis_assist'

class Person < RedisAssist::Base
  redis_persist :name
  has_many      :pets
end

class Pet < RedisAssist::Base
  redis_persist :name
  belongs_to    :person
end

describe Person do
  let(:hubble) { Pet.new(name: 'Hubble Love') }
  let(:oliver) { Pet.new(name: 'Oliver Bear Love') }
  let(:person) do
    person = Person.new(name: 'Tyler Love') 
    person.save
  end

  before do
    person.add_pet hubble
    person.add_pet oliver
    person.save
  end

  describe "#has_many" do
    subject       { binding.pry; person.pets }
    its(:length)  { should eq 2 }
  end

  describe "#belongs_to" do
    subject         { oliver }
    its(:id)        { should }
    its(:person_id) { should eq person.id }
    it "should find the same person" do
      cat = Pet.find(oliver.id)
      cat.person.id.should eq person.id
      cat.person_id.should eq person.id
    end
  end
end
