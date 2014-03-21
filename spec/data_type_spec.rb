require 'spec_helper'

class TestType < RedisAssist::DataType
  commands %w(
    dosomething 
    dosomethingelse
  )
end

describe TestType do
  describe '#commands' do
    context 'singleton' do
      subject        { TestType }
      its(:commands) { should eq ['dosomething', 'dosomethingelse'] }
      it "defined class methods" do
        should respond_to(:dosomething)
        should respond_to(:dosomethingelse)
      end
    end

    context 'instance' do
      subject { TestType.new(key: 'abcd') }

      it "defined instance methods" do
        subject.respond_to? :dosomething
      end
    end
  end

  describe '#new' do
    subject   { TestType.new(key: 'abcd') }
    its(:key) { should eq 'abcd' }
    it 'raises a unknown command error' do
      expect { subject.dosomething }.to raise_error Redis::CommandError
    end
  end
end

describe RedisAssist::SortedSet do
  subject { RedisAssist::SortedSet.new(key: 'test:data_type:sorted_set') }
end

# class Person < RedisAssist::Base
#   attr_persist  :name
#   has_many      :pets
# end
# 
# class Pet < RedisAssist::Base
#   attr_persist  :name
#   belongs_to    :person
# end
# 
# describe Person do
#   let(:hubble) { Pet.new(name: 'Hubble Love') }
#   let(:oliver) { Pet.new(name: 'Oliver Bear Love') }
#   let(:person) do
#     person = Person.new(name: 'Tyler Love') 
#     person.save
#   end
# 
#   before do
#     person.add_pet hubble
#     person.add_pet oliver
#     person.save
#   end
# 
#   describe "#has_many" do
#     subject       { person.pets }
#     its(:length)  { should eq 2 }
#   end
# 
#   describe "#belongs_to" do
#     subject         { oliver }
#     its(:id)        { should }
#     its(:person_id) { should eq person.id }
#     it "should find the same person" do
#       cat = Pet.find(oliver.id)
#       cat.person.id.should eq person.id
#       cat.person_id.should eq person.id
#     end
#   end
# end
