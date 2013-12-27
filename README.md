RedisAssist - Easy Redis Backed Object Modeling
==============================================

Documentation: http://www.rubydoc.info/github/endlessinc/redis_assist/frames

RedisAssist is a Persistant Object Model backed by Redis for Ruby.

Store and Fetch data of any type in Redis with as little friction as possible. RedisAssist lets you back simple or complex Object Models with Redis while giving you a convenient interface interact with it.


## Getting Started
In your Gemfile:

    gem "redis_assist"

Create a model:

    class Person < RedisAssist::Base
      attr_persist :name
      attr_persist :birthday,     as: :time
      attr_persist :meta_info,    as: :json
      attr_persist :created_at,   as: :time # Magic date fields just like ActiveRecord.
    
      def validate
        add_error(:name, "Albert Einstein is dead.") if name.eql?('Albert Eintein')
      end 
    end


## Saving
    person = Person.new(name: 'Albert Hoffman', birthday: Time.parse('1/11/1906'), meta_info: { profession: 'Scientist' })
    person.new_record?  # => true
    person.name         # => "Albert Hoffman"
    person.save         # => #<Person:0x007f88341662a0>
    person.new_record?  # => false


## Creating
    person = Person.create(name: 'Albert Hoffman', birthday: Time.parse('1/11/1906'), meta_info: { profession: 'Scientist' })

## Updating
With an instance
    person = Person.find(1)
    person.name = 'Hubble Love'
    person.save


Skip callbacks / validations
    person.update_columns(name: 'Tyler Love', birthday: Time.parse('1/11/1908'))
    

With only an id, this will hit callbacks and validations
    Person.update(1, name: 'Tyler Love')



## Validating
    person = Person.new(name: 'Albert Einstein', birthday: Time.parse('1/11/1906'), meta_info: { profession: 'Scientist' })
    persin.valid?       # => false
    persin.errors       # => [{name: "Albert Einstein is dead."}]


## Fetching
Find by id
    person = Person.find(1)


Find an array of people
    # returns an array of people
    people = Person.find([1, 2])


Find the last people
    # Finds the last person created
    people = People.last

    # Finds the last `10` people created 
    people = People.last(10)

    # Find `10` people, offset from the end of the `id` index by `30`
    people = People.last(10, 30)


Find the first people
    # Finds the first person created
    people = People.first

    # Finds the first `10` people created 
    people = People.first(10)

    # Find `10` people offset from the beginning of the `id` index by `30`
    people = People.first(10, 30)


Find all of the people. WARNING: If you have large data sets, you should use `find_in_batches` instead.
    people = Person.all
    

## Find In Batches
Works just like the ActiveRecord `find_in_batches`. The most performant way to iterate over large data sets
    # Supports options 
    # `batch_size` the amount of records to find in each batch. Default is `500`
    # `offset` offset from the begining of the `id` index
    People.find_in_batches do |people|
      people.each do |person|
        # do something with a person
      end
    end

## Deleting
Deletes all the persisted attributes from redis.

    person = Person.find(1)
    person.delete       # => true

"Soft delete" is built into RedisAssist. Simply add a deleted\_at property to your model.

    attr_persist :deleted_at, as: :time 

You can fetch soft deleted records by setting a `deleted` property when calling `#find`

    Person.find(1, deleted: true)


## Callbacks
RedisAssist supports callbacks through a Rails like interface.

    before_save :titleize_blog_title
    after_create :send_to_real_time_sphinx_index
    after_update :update_in_realtime_sphinx_index

    after_delete do |record|
      record.cleanup!
    end

    def titleize_blog_title 
      blog_title.titleize!
    end

    def send_to_realtime_sphinx_index
      ...
    end

    def update_in_realtime_sphinx_index
      ...
    end

## Relationships
Experimental support for has_many and belongs_to relationships.

    class Person < RedisAssist::Base
      attr_persist  :name
      has_many      :pets
    end
            
    class Pet < RedisAssist::Base
      attr_persist  :name
      belongs_to    :person
    end

    person = Person.create(name: 'Tyler Love')
    person.add_pet Pet.new('Hubble Love')
    person.add_pet Pet.new('Oliver Love')
    person.save

    person.pet_ids      # => [1,2]
    person.pets         # => [..pets..]

    pet = Pet.find(1) 
    pet.person

## Helpful methods
    # The Redis client used for this module 
    client = People.redis


## Transforms
Since Redis only supports string values RedisAssist provides an interface for serialization in and out of Redis.

Currently RedisAssist natively supports the following types.

* String `default`
* Boolean
* Float
* Integer
* JSON
* Time
* list *native redis list data type*
* hash *native redis hash data type*

RedisAssist also provides an elegant API for defining custom transforms.
    
    # Serialize/Deserialize objects with the MessagePack gem
    class MessagePackTransform < RedisAssist::Transform
      def self.to(val)
        val.to_msgpack
      end

      def self.from(val)
        MessagePack.unpack(val) 
      end
    end

To use the MessagePackTransform we just defined

    attr_persist :really_long_biography, as: :message_pack      


## Useful Info

RedisAssist takes advantage of redis hashes to store each persisted attribute. Using the `Person` module as an example, the fields will be stored as a Redis Hash with the key `person:[id]:attributes`. Several other design approaches were considered. This method was selected because 1) it keeps the underlying data structures flat and normalized in Redis 2) Offers Redis Hash performance benefits, as outlined here: http://redis.io/topics/memory-optimization

Hundreds of millions of RedisAssist creates, updates, finds, and saves are called on bustle.com every month. 


## In the works
* Refactor an internal API to add more robust support for native Redis data types. Currently there is basic support for lists and hashes. We intend to add advanced support for all Redis data types.
* Refactoring relationship support. RedisAssist relations are not an attempt to recreate SQL joins. The goal is to provide a convenient API for ordering, sorting, iterating over your data sets. It will never do everything a SQL `JOIN` will do, but it introduces many other practical ways of organizing, reading, and writing your data sets.
* Cleanup and 1.0
* Utilities to help with data migrations.
* `redis_assist_index` a seperate gem that adds native support for storing your redis models in Sphinx real-time indexes. Full super advanced full-text search, facets, sorting, etc. Hit me up at `product@bustle.com` if you're interested.

## Requirements
    redis-rb


## Configuration
You can configure RedisAssist with your own redis client

    RedisAssist::Config.redis = Redis.new([connection settings...])
