require 'spec_helper'

# Spec to make sure the sorted set index is working
# Also a good place to check that features that use the
# index are working
describe Person do
  let(:first)           { 'Bobby' }
  let(:last)            { 'Brown' }
  let(:birthday)        { Time.parse('4/10/1972') }
  let(:drugs)           { ['heroin', 'LSD', 'Psilocybin Mushrooms'] }
  let(:info)            { { "happy" => 'Yes', "hair" => 'Brown', "dick" => 'Big' } }
  let(:favorite_number) { 666 }
  let(:attrs)           { { first: first, last: last, birthday: birthday, drugs: drugs, favorite_number: favorite_number, info: info } }
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
      index = Person.redis.zrank(Person.index_key_for(:deleted), person.id)
      index.should be_a Integer
    end

  end
end
