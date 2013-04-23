require 'redis_assist'

class Person < RedisAssist::Base
  attr_persist  :name
  has_many      :pets
end

class Pet < RedisAssist::Base
  attr_persist  :name
  belongs_to    :person
end

describe Person do
  let(:hubble) { Pet.new(name: 'Hubble Love') }
  let(:oliver) { Pet.new(name: 'Oliver Bear Love') }
  let(:person) do
    person = Person.new(name: 'Tyler Love ') 
    person.save
    person.add_pet hubble
    person.add_pet oliver
    person
  end

  describe "#has_many" do
    subject       { person }
    its(:pets)    { subject.length.should eq 2 }
    its(:pet_ids) { subject.inspect; subject.length.should eq 2 }
  end

  describe "#belongs_to" do
    subject         { oliver }
    its(:id)        { should }
    its(:person_id) { should eq person.id }
  end

end
