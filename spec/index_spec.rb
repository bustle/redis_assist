require 'spec_helper'

# Spec to make sure the sorted set index is working
# Also a good place to check that features that use the
# index are working
describe Person do
  let(:first)           { 'Bobby' }
  let(:last)            { 'Brown' }
  let(:birthday)        { Time.parse('4/10/1972') }
  let(:toys)            { ['cars', 'bikes', 'dolls'] }
  let(:info)            { { "happy" => 'Yes', "hair" => 'Brown', "dick" => 'Big' } }
  let(:favorite_number) { 666 }
  let(:attrs)           { { first: first, last: last, birthday: birthday, toys: toys, favorite_number: favorite_number, info: info } }
  let(:person)          { Person.new(attrs) }

  before  { person.save }
  subject { person }

  context "saved" do
    it "should be in the id index" do
      index = Person.redis.zrank(Person.index_key_for(:id), person.id)
      index.should be_a Integer
    end

    it "should not be in the deleted index" do
      index = Person.redis.zrank(Person.index_key_for(:deleted), person.id)
      index.should_not be_a Integer
    end
  end

  context "deleted" do
    before { person.delete }

    it "should not be in the id index" do
      index = Person.redis.zrank(Person.index_key_for(:id), person.id)
      index.should_not be_a Integer
    end

    it "should be in the deleted index" do
      index = Person.redis.zrank(Person.index_key_for(:deleted_at), person.id)
      index.should be_a Integer
    end

  end

  describe "#find_in_batches" do
    it "should batch shit up" do
      people      = []
      batch_count = 0

      Person.find_in_batches(batch_size: 10) do |person_batch|
        people = people + person_batch 
        batch_count += 1
      end

      people.length.should > 0
      batch_count.should > 0
    end
  end

  describe "#count" do
    it "should have a count" do
      Person.count.should be_a Integer
      Person.count.should > 0
    end
  end

  describe ".last" do
    it "should find the last person" do
    end
  end

  describe ".first" do
    it "should find the first person" do
      Person.first.should be_a Person
    end
  end

  describe ".last" do
    it "should find the first person" do
      Person.last.id.should eq person.id
    end
  end
end
