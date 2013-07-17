require 'spec_helper'

describe Person do
  let(:first)           { 'Bobby' }
  let(:last)            { 'Brown' }
  let(:birthday)        { Time.parse('4/10/1972') }
  let(:drugs)           { ['heroin', 'LSD', 'Psilocybin Mushrooms'] }
  let(:info)            { { "happy" => 'Yes', "hair" => 'Brown', "dick" => 'Big' } }
  let(:favorite_number) { 666 }
  let(:attrs)           { { first: first, last: last, birthday: birthday, drugs: drugs, favorite_number: favorite_number, info: info } }
  let(:person)          { Person.new(attrs) }

  subject { person }

  context "saving" do
    describe "#create" do
      let(:person)  { Person.create(attrs) }
      subject       { person }
      its(:id)      { should }
      it            { subject.new_record?.should_not }
    end

    describe ".save" do
      before    { person.save }
      its(:id)  { should }
      it        { subject.new_record?.should_not }
    end

    describe ".valid?" do
      let(:bad_attrs) { attrs.merge(first: 'RJ') }
      subject         { Person.new(bad_attrs) }
      its(:save)      { should_not }
      its(:errors)    { subject.empty?.should_not }
      it              { subject.valid?.should_not }
    end
  end

  context "finding" do
    before { person.save }

    describe "#find" do
      let(:found)   { Person.find(person.id) }
      subject       { found }
      its(:id)      { should eq person.id }

      context "finding deleted" do
        before  { subject.delete }
        it { Person.find(subject.id).should_not }
        it { Person.find(subject.id, deleted: true).id.should eq subject.id}
      end
    end

    describe "#find_by_id" do
      let(:found)   { Person.find_by_id(person.id) }
      subject       { found }
      its(:id)      { should eq person.id }
      its(:first)   { should eq person.first }
      it            { Person.find_by_id("fakeid").should eq nil }
    end

    describe "#find_by_ids" do
      let(:second_person) { Person.new(attrs.merge(first: 'Garth', last: 'Portrais')) }
      before do
        second_person.save
        person.save
      end
      it { Person.find_by_ids([person.id, second_person.id]).is_a?(Array).should }
      it { Person.find_by_ids([person.id, second_person.id]).length.should eq 2 }
      it { Person.find_by_ids(["fakefuckingid"]).should eq [] }
    end

    describe "#exists?" do
      subject { person }
      it      { Person.exists?(person.id).should }
      it      { Person.exists?(rand(123456789)).should_not }
    end
  end

  context "updating" do
    describe ".save" do
      before do 
        person.save 
        person.first = 'Garth'
        person.save
      end

      subject     { Person.find(person.id) }
      its(:first) { should eq 'Garth' }
    end

    describe "#update" do
      before do 
        person.save
        Person.update(person.id, last: 'Dick Brain', birthday: birthday, drugs: ['weed'], smokes_weed: false, info: { 'super' => 'cool' })
      end

      subject           { Person.find(person.id) }
      # its(:last)        { should eq 'Dick Brain' }
      its(:birthday)    { should eq birthday }
      # its(:drugs)       { should eq ['weed'] }
      # its(:smokes_weed) { should eq false }
      # its(:info)        { should eq({ 'super' => 'cool' }) }
    end
  end

  context "attribute type conversions" do
    before  { person.save }
    subject { Person.find(person.id) }

    its(:first)       { should eq first }
    its(:birthday)    { should eq birthday }
    its(:drugs)       { should eq drugs }
    its(:info)        { should eq info }
  end

  context "default values are respected" do
    before { person.save }
    its(:smokes_weed) { should }
    its(:title)       { should eq "Runt" }
  end

  context "deleting" do
    describe ".delete" do
      before do
        person.save
        person.delete
      end

      subject { Person.find_by_id(person.id) }

      it { should_not }
    end
  end

  context "associations" do
    before { person.save }
  end
end
