ReactiveVar = require 'meteor/reactive-var'

for idGeneration in ['STRING', 'MONGO']
  do (idGeneration) ->
    allCollections = []

    if idGeneration is 'STRING'
      generateId = ->
        Random.id()
    else
      generateId = ->
        new Meteor.Collection.ObjectID()

    Users = new Mongo.Collection "Users_meteor_reactivepublish_tests_#{idGeneration}", {idGeneration}
    Posts = new Mongo.Collection "Posts_meteor_reactivepublish_tests_#{idGeneration}", {idGeneration}
    Addresses = new Mongo.Collection "Addresses_meteor_reactivepublish_tests_#{idGeneration}", {idGeneration}
    Fields = new Mongo.Collection "Fields_meteor_reactivepublish_tests_#{idGeneration}", {idGeneration}

    allCollections.push Users
    allCollections.push Posts
    allCollections.push Addresses
    allCollections.push Fields

    if Meteor.isServer
      LocalCollection = new Mongo.Collection null, {idGeneration}

      localCollectionLimit = new ReactiveVar null

      Meteor.publish null, ->
        Users.find()

      Meteor.publish "posts_#{idGeneration}", (ids) ->
        Posts.find
          _id:
            $in: ids

      Meteor.publish "users-posts_#{idGeneration}", (userId) ->
        handle = Tracker.autorun (computation) =>
          user = Users.findOne userId,
            fields:
              posts: 1

          projectedField = Fields.findOne userId

          Posts.find(
            _id:
              $in: user?.posts or []
          ,
            fields: _.omit (projectedField or {}), '_id'
          ).observeChanges
            added: (id, fields) =>
              assert not Tracker.active
              fields.dummyField = true
              @added "Posts_meteor_reactivepublish_tests_#{idGeneration}", id, fields
            changed: (id, fields) =>
              assert not Tracker.active
              @changed "Posts_meteor_reactivepublish_tests_#{idGeneration}", id, fields
            removed: (id) =>
              assert not Tracker.active
              @removed "Posts_meteor_reactivepublish_tests_#{idGeneration}", id

          @ready()

        @onStop =>
          handle?.stop()
          handle = null

      Meteor.publish "users-posts-foreach_#{idGeneration}", (userId) ->
        # Handle is being returned and stopped automatically.
        Tracker.autorun (computation) =>
          user = Users.findOne userId,
            fields:
              posts: 1

          projectedField = Fields.findOne userId

          Posts.find(
            _id:
              $in: user?.posts or []
          ,
            fields: _.omit (projectedField or {}), '_id'
          ).forEach (document, i, cursor) =>
            fields = _.omit document, '_id'
            fields.dummyField = true
            @added "Posts_meteor_reactivepublish_tests_#{idGeneration}", document._id, fields

          @ready()

      Meteor.publish "users-posts-autorun_#{idGeneration}", (userId) ->
        # Handle is being returned and stopped automatically.
        Tracker.autorun (computation) =>
          user = Users.findOne userId,
            fields:
              posts: 1

          projectedField = Fields.findOne userId

          Tracker.autorun (computation) =>
            Posts.find(
              _id:
                $in: user?.posts or []
            ,
              fields: _.omit (projectedField or {}), '_id'
            ).forEach (document, i, cursor) =>
              fields = _.omit document, '_id'
              fields.dummyField = true
              @added "Posts_meteor_reactivepublish_tests_#{idGeneration}", document._id, fields

          @ready()

      Meteor.publish "users-posts-method_#{idGeneration}", (userId) ->
        # Handle is being returned and stopped automatically.
        Tracker.autorun (computation) =>
          {user, projectedField} = Meteor.call "userAndProjection_#{idGeneration}", userId

          Posts.find(
            _id:
              $in: user?.posts or []
          ,
            fields: _.omit (projectedField or {}), '_id'
          ).observeChanges
            added: (id, fields) =>
              assert not Tracker.active
              fields.dummyField = true
              @added "Posts_meteor_reactivepublish_tests_#{idGeneration}", id, fields
            changed: (id, fields) =>
              assert not Tracker.active
              @changed "Posts_meteor_reactivepublish_tests_#{idGeneration}", id, fields
            removed: (id) =>
              assert not Tracker.active
              @removed "Posts_meteor_reactivepublish_tests_#{idGeneration}", id

          @ready()

      Meteor.publish "users-posts-and-addresses_#{idGeneration}", (userId) ->
        self = @

        @autorun (computation) ->
          # To test that a computation is bound to the publish.
          assert.equal @, self

          user1 = Users.findOne userId,
            fields:
              posts: 1

          Posts.find(
            _id:
              $in: user1?.posts or []
          )

        @autorun (computation) =>
          user2 = Users.findOne userId,
            fields:
              addresses: 1

          Addresses.find(
            _id:
              $in: user2?.addresses or []
          )

      Meteor.publish "users-posts-and-addresses-together_#{idGeneration}", (userId) ->
        @autorun (computation) =>
          user = Users.findOne userId,
            fields:
              posts: 1
              addresses: 1

          [
            Posts.find(
              _id:
                $in: user?.posts or []
            )
          ,
            Addresses.find(
              _id:
                $in: user?.addresses or []
            )
          ]

      Meteor.publish "users-posts-count_#{idGeneration}", (userId, countId) ->
        @autorun (computation) =>
          user = Users.findOne userId,
            fields:
              posts: 1

          count = 0
          initializing = true

          Posts.find(
            _id:
              $in: user?.posts or []
          ).observeChanges
            added: (id) =>
              assert not Tracker.active
              count++
              @changed "Counts_#{idGeneration}", countId, count: count unless initializing
            removed: (id) =>
              assert not Tracker.active
              count--
              @changed "Counts_#{idGeneration}", countId, count: count unless initializing

          initializing = false

          @added "Counts_#{idGeneration}", countId,
            count: count

          @ready()

      currentTime = new ReactiveVar Date.now()

      Meteor.setInterval ->
        currentTime.set Date.now()
        # Using 1 ms to stress-test the system. In practice you should be using a much larger interval.
      , 1 # ms

      Meteor.publish "recent-posts_#{idGeneration}", ->
        @autorun (computation) =>
          timestamp = currentTime.get() - 2000 # ms

          Posts.find(
            timestamp:
              $exists: true
              $gte: timestamp
          ,
            sort:
              timestamp: 1
          )

      # Error is expected.
      Meteor.publish "multiple-cursors-1_#{idGeneration}", ->
        @autorun (computation) =>
          Posts.find()

        @autorun (computation) =>
          Posts.find()

      # Error is expected.
      Meteor.publish "multiple-cursors-2_#{idGeneration}", ->
        @autorun (computation) =>
          Posts.find()

        Posts.find()

      Meteor.publish "localCollection_#{idGeneration}", ->
        @autorun (computation) =>
          LocalCollection.find({}, {sort: {i: 1}, limit: localCollectionLimit.get()}).observeChanges
            addedBefore: (id, fields, before) =>
              @added "localCollection_#{idGeneration}", id, fields
            changed: (id, fields) =>
              @changed "localCollection_#{idGeneration}", id, fields
            removed: (id) =>
              @removed "localCollection_#{idGeneration}", id

          @ready()

      Meteor.publish "unblocked-users-posts_#{idGeneration}", (userId) ->
        @unblock()

        @autorun (computation) =>
          user = Users.findOne userId,
            fields:
              posts: 1

          Posts.find(
            _id:
              $in: user?.posts or []
          )

      methods = {}
      methods["insertPost_#{idGeneration}"] = (timestamp) ->
        check timestamp, Number

        Posts.insert
          timestamp: timestamp

      methods["userAndProjection_#{idGeneration}"] = (userId) ->
        user = Users.findOne userId,
          fields:
            posts: 1

        projectedField = Fields.findOne userId

        {user, projectedField}

      methods["setLocalCollectionLimit_#{idGeneration}"] = (limit) ->
        localCollectionLimit.set limit

      methods["insertLocalCollection_#{idGeneration}"] = (doc) ->
        LocalCollection.insert doc

      # We use our own insert method to not have latency compensation so that observeChanges
      # on the client really matches how databases changes on the server.
      Meteor.methods methods

    else
      LocalCollection = new Mongo.Collection "localCollection_#{idGeneration}", {idGeneration}

    localMethods = {}
    localMethods["clearLocalCollection_#{idGeneration}"] = ->
      LocalCollection.remove {}

    Meteor.methods localMethods

    class ReactivePublishTestCase extends ClassyTestCase
      @testName: "reactivepublish - #{idGeneration}"

      setUpServer: ->
        # Initialize the database.
        Users.remove {}
        Posts.remove {}
        Addresses.remove {}
        Fields.remove {}

      setUpClient: ->
        @countsCollection ?= new Mongo.Collection "Counts_#{idGeneration}", {idGeneration}

      @basic: (publishName) -> [
        ->
          @userId = generateId()
          @countId = generateId()

          @assertSubscribeSuccessful "#{publishName}_#{idGeneration}", @userId, @expect()
          @assertSubscribeSuccessful "users-posts-count_#{idGeneration}", @userId, @countId, @expect()
      ,
        ->
          @assertEqual Posts.find().fetch(), []
          @assertEqual @countsCollection.findOne(@countId)?.count, 0

          @posts = []

          for i in [0...10]
            Posts.insert {}, @expect (error, id) =>
              @assertFalse error, error?.toString?() or error
              @assertTrue id
              @posts.push id

          Meteor.setTimeout @expect(), 200 # ms
      ,
        ->
          @assertEqual Posts.find().fetch(), []
          @assertEqual @countsCollection.findOne(@countId)?.count, 0

          Users.insert
            _id: @userId
            posts: @posts
          ,
            @expect (error, userId) =>
              @assertFalse error, error?.toString?() or error
              @assertTrue userId
              @assertEqual userId, @userId

          Meteor.setTimeout @expect(), 200 # ms
      ,
        ->
          Posts.find().forEach (post) =>
            @assertTrue post.dummyField
          @assertItemsEqual _.pluck(Posts.find().fetch(), '_id'), @posts
          @assertEqual @countsCollection.findOne(@countId)?.count, @posts.length

          @shortPosts = @posts[0...5]

          Users.update @userId,
            posts: @shortPosts
          ,
            @expect (error, count) =>
              @assertFalse error, error?.toString?() or error
              @assertEqual count, 1

          Meteor.setTimeout @expect(), 200 # ms
      ,
        ->
          Posts.find().forEach (post) =>
            @assertTrue post.dummyField
          @assertItemsEqual _.pluck(Posts.find().fetch(), '_id'), @shortPosts
          @assertEqual @countsCollection.findOne(@countId)?.count, @shortPosts.length

          Users.update @userId,
            posts: []
          ,
            @expect (error, count) =>
              @assertFalse error, error?.toString?() or error
              @assertEqual count, 1

          Meteor.setTimeout @expect(), 200 # ms
      ,
        ->
          @assertItemsEqual _.pluck(Posts.find().fetch(), '_id'), []
          @assertEqual @countsCollection.findOne(@countId)?.count, 0

          Users.update @userId,
            posts: @posts
          ,
            @expect (error, count) =>
              @assertFalse error, error?.toString?() or error
              @assertEqual count, 1

          Meteor.setTimeout @expect(), 200 # ms
      ,
        ->
          Posts.find().forEach (post) =>
            @assertTrue post.dummyField, true
          @assertItemsEqual _.pluck(Posts.find().fetch(), '_id'), @posts
          @assertEqual @countsCollection.findOne(@countId)?.count, @posts.length

          Posts.remove @posts[0], @expect (error, count) =>
            @assertFalse error, error?.toString?() or error
            @assertEqual count, 1

          Meteor.setTimeout @expect(), 200 # ms
      ,
        ->
          Posts.find().forEach (post) =>
            @assertTrue post.dummyField
          @assertItemsEqual _.pluck(Posts.find().fetch(), '_id'), @posts[1..]
          @assertEqual @countsCollection.findOne(@countId)?.count, @posts.length - 1

          Users.remove @userId,
            @expect (error) =>
              @assertFalse error, error?.toString?() or error

          Meteor.setTimeout @expect(), 200 # ms
      ,
        ->
          @assertItemsEqual _.pluck(Posts.find().fetch(), '_id'), []
          @assertEqual @countsCollection.findOne(@countId)?.count, 0
      ]

      testClientBasic: @basic 'users-posts'

      testClientBasicForeach: @basic 'users-posts-foreach'

      testClientBasicAutorun: @basic 'users-posts-autorun'

      testClientBasicMethod: @basic 'users-posts-method'

      @unsubscribing: (publishName) -> [
        ->
          @userId = generateId()
          @countId = generateId()

          @assertSubscribeSuccessful "#{publishName}_#{idGeneration}", @userId, @expect()
          @assertSubscribeSuccessful "users-posts-count_#{idGeneration}", @userId, @countId, @expect()
      ,
        ->
          @assertEqual Posts.find().fetch(), []
          @assertEqual @countsCollection.findOne(@countId)?.count, 0

          @posts = []

          for i in [0...10]
            Posts.insert {}, @expect (error, id) =>
              @assertFalse error, error?.toString?() or error
              @assertTrue id
              @posts.push id

          Meteor.setTimeout @expect(), 200 # ms
      ,
        ->
          @assertEqual Posts.find().fetch(), []
          @assertEqual @countsCollection.findOne(@countId)?.count, 0

          Users.insert
            _id: @userId
            posts: @posts
          ,
            @expect (error, userId) =>
              @assertFalse error, error?.toString?() or error
              @assertTrue userId
              @assertEqual userId, @userId

          Meteor.setTimeout @expect(), 200 # ms
      ,
        ->
          Posts.find().forEach (post) =>
            @assertTrue post.dummyField
          @assertItemsEqual _.pluck(Posts.find().fetch(), '_id'), @posts
          @assertEqual @countsCollection.findOne(@countId)?.count, @posts.length

          # We have to update posts to trigger at least one rerun.
          Users.update @userId,
            posts: _.shuffle @posts
          ,
            @expect (error, count) =>
              @assertFalse error, error?.toString?() or error
              @assertEqual count, 1

          Meteor.setTimeout @expect(), 200 # ms
      ,
        ->
          Posts.find().forEach (post) =>
            @assertTrue post.dummyField
          @assertItemsEqual _.pluck(Posts.find().fetch(), '_id'), @posts
          @assertEqual @countsCollection.findOne(@countId)?.count, @posts.length

          callback = @expect()
          @postsSubscribe = Meteor.subscribe "posts_#{idGeneration}", @posts,
            onReady: callback
            onError: (error) =>
              @assertFail
                type: 'subscribe'
                message: "Subscrption to endpoint failed, but should have succeeded."
              callback()
          @unsubscribeAll()

          Meteor.setTimeout @expect(), 2000
      ,
        ->
          # After unsubscribing from the reactive publish which added dummyField,
          # dummyField should be removed from documents available on the client side
          Posts.find().forEach (post) =>
            @assertIsUndefined post.dummyField
          @assertItemsEqual _.pluck(Posts.find().fetch(), '_id'), @posts

          @postsSubscribe.stop()
      ]

      testClientUnsubscribing: @unsubscribing 'users-posts'

      testClientUnsubscribingForeach: @unsubscribing 'users-posts-foreach'

      testClientUnsubscribingAutorun: @unsubscribing 'users-posts-autorun'

      testClientUnsubscribingMethod: @unsubscribing 'users-posts-method'

      @removeField: (publishName) -> [
        ->
          @userId = generateId()

          @assertSubscribeSuccessful "#{publishName}_#{idGeneration}", @userId, @expect()
      ,
        ->
          @assertEqual Posts.find().fetch(), []

          Fields.insert
            _id: @userId
            foo: 1
            dummyField: 1
          ,
            @expect (error, id) =>
              @assertFalse error, error?.toString?() or error
              @assertTrue id
              @fieldsId = id

          Posts.insert {foo: 'bar'}, @expect (error, id) =>
            @assertFalse error, error?.toString?() or error
            @assertTrue id
            @postId = id

          Meteor.setTimeout @expect(), 200 # ms
      ,
        ->
          @assertEqual Posts.find().fetch(), []

          Users.insert
            _id: @userId
            posts: [@postId]
          ,
            @expect (error, userId) =>
              @assertFalse error, error?.toString?() or error
              @assertTrue userId
              @assertEqual userId, @userId

          Meteor.setTimeout @expect(), 200 # ms
      ,
        ->
          @assertItemsEqual Posts.find().fetch(), [
            _id: @postId
            foo: 'bar'
            dummyField: true
          ]

          Posts.update @postId,
            $set:
              foo: 'baz'
          ,
            @expect (error, count) =>
              @assertFalse error, error?.toString?() or error
              @assertEqual count, 1

          Meteor.setTimeout @expect(), 200 # ms
      ,
        ->
          @assertItemsEqual Posts.find().fetch(), [
            _id: @postId
            foo: 'baz'
            dummyField: true
          ]

          Posts.update @postId,
            $unset:
              foo: ''
          ,
            @expect (error, count) =>
              @assertFalse error, error?.toString?() or error
              @assertEqual count, 1

          Meteor.setTimeout @expect(), 200 # ms
      ,
        ->
          @assertItemsEqual Posts.find().fetch(), [
            _id: @postId
            dummyField: true
          ]

          Posts.update @postId,
            $set:
              foo: 'bar'
          ,
            @expect (error, count) =>
              @assertFalse error, error?.toString?() or error
              @assertEqual count, 1

          Meteor.setTimeout @expect(), 200 # ms
      ,
        ->
          @assertItemsEqual Posts.find().fetch(), [
            _id: @postId
            foo: 'bar'
            dummyField: true
          ]

          Fields.update @userId,
            $unset:
              foo: ''
          ,
            @expect (error, count) =>
              @assertFalse error, error?.toString?() or error
              @assertEqual count, 1

          Meteor.setTimeout @expect(), 200 # ms
      ,
        ->
          @assertItemsEqual Posts.find().fetch(), [
            _id: @postId
            dummyField: true
          ]
      ]

      testClientRemoveField: @removeField 'users-posts'

      testClientRemoveFieldForeach: @removeField 'users-posts-foreach'

      testClientRemoveFieldAutorun: @removeField 'users-posts-autorun'

      testClientRemoveFieldMethod: @removeField 'users-posts-method'

      @multiple: (publishName) -> [
        ->
          @userId = generateId()

          @assertSubscribeSuccessful "#{publishName}_#{idGeneration}", @userId, @expect()
        ->
          @assertEqual Posts.find().fetch(), []
          @assertEqual Addresses.find().fetch(), []

          @posts = []

          for i in [0...10]
            Posts.insert {}, @expect (error, id) =>
              @assertFalse error, error?.toString?() or error
              @assertTrue id
              @posts.push id

          @addresses = []

          for i in [0...10]
            Addresses.insert {}, @expect (error, id) =>
              @assertFalse error, error?.toString?() or error
              @assertTrue id
              @addresses.push id

          Meteor.setTimeout @expect(), 200 # ms
      ,
        ->
          @assertEqual Posts.find().fetch(), []
          @assertEqual Addresses.find().fetch(), []

          Users.insert
            _id: @userId
            posts: @posts
            addresses: @addresses
          ,
            @expect (error, userId) =>
              @assertFalse error, error?.toString?() or error
              @assertTrue userId
              @assertEqual userId, @userId

          Meteor.setTimeout @expect(), 200 # ms
      ,
        ->
          @assertItemsEqual _.pluck(Posts.find().fetch(), '_id'), @posts
          @assertItemsEqual _.pluck(Addresses.find().fetch(), '_id'), @addresses

          Users.update @userId,
            $set:
              posts: @posts[0..5]
          ,
            @expect (error, count) =>
              @assertFalse error, error?.toString?() or error
              @assertEqual count, 1

          Meteor.setTimeout @expect(), 200 # ms
      ,
        ->
          @assertItemsEqual _.pluck(Posts.find().fetch(), '_id'), @posts[0..5]
          @assertItemsEqual _.pluck(Addresses.find().fetch(), '_id'), @addresses

          Users.update @userId,
            $set:
              addresses: @addresses[0..5]
          ,
            @expect (error, count) =>
              @assertFalse error, error?.toString?() or error
              @assertEqual count, 1

          Meteor.setTimeout @expect(), 200 # ms
      ,
        ->
          @assertItemsEqual _.pluck(Posts.find().fetch(), '_id'), @posts[0..5]
          @assertItemsEqual _.pluck(Addresses.find().fetch(), '_id'), @addresses[0..5]

          Users.update @userId,
            $unset:
              addresses: ''
          ,
            @expect (error, count) =>
              @assertFalse error, error?.toString?() or error
              @assertEqual count, 1

          Meteor.setTimeout @expect(), 200 # ms
      ,
        ->
          @assertItemsEqual _.pluck(Posts.find().fetch(), '_id'), @posts[0..5]
          @assertItemsEqual _.pluck(Addresses.find().fetch(), '_id'), []

          Users.remove @userId, @expect (error, count) =>
            @assertFalse error, error?.toString?() or error
            @assertEqual count, 1

          Meteor.setTimeout @expect(), 200 # ms
      ,
        ->
          @assertItemsEqual _.pluck(Posts.find().fetch(), '_id'), []
          @assertItemsEqual _.pluck(Addresses.find().fetch(), '_id'), []
      ]

      testClientMultiple: @multiple 'users-posts-and-addresses'

      testClientMultipleTogether: @multiple 'users-posts-and-addresses-together'

      testClientReactiveTime: [
        ->
          @assertSubscribeSuccessful "recent-posts_#{idGeneration}", @expect()

          @changes = []

          @handle = Posts.find(
            timestamp:
              $exists: true
          ).observeChanges
            added: (id, fields) =>
              @changes.push {added: id, timestamp: Date.now()}
            changes: (id, fields) =>
              @assertFail()
            removed: (id) =>
              @changes.push {removed: id, timestamp: Date.now()}
        ->
          @assertEqual Posts.find(timestamp: $exists: true).fetch(), []

          @posts = []

          for i in [0...10]
            timestamp =  Date.now() + i * 91 # ms
            do (timestamp) =>
              # We use a method to not have any client-side simulation which can
              # interfere with the observation of the Posts collection.
              Meteor.call "insertPost_#{idGeneration}", timestamp, @expect (error, id) =>
                @assertFalse error, error?.toString?() or error
                @assertTrue id
                @posts.push
                  _id: id
                  timestamp: timestamp

          # We have to wait for all posts to be inserted and pushed to the client.
          Meteor.setTimeout @expect(), 300 # ms
        ->
          @posts = _.sortBy @posts, 'timestamp'

          @assertEqual Posts.find(
            timestamp:
              $exists: true
          ,
            sort:
              timestamp: 1
          ).fetch(), @posts

          # We wait for 2000 ms for all documents to be removed, and then a bit more
          # to make sure the publish endpoint gets synced to the client.
          Meteor.setTimeout @expect(), 3000 # ms
        ->
          @assertEqual Posts.find(
            timestamp:
              $exists: true
          ).fetch(), []

          @assertEqual @changes.length, 20

          postsId = _.pluck @posts, '_id'
          # There should be first changes for adding, in possibly different order.
          @assertItemsEqual (change.added for change in @changes when change.added), postsId
          # And then in the known order changes for removing.
          @assertEqual (change.removed for change in @changes when change.removed), postsId

          addedTimestamps = (change.timestamp for change in @changes when change.added)
          removedTimestamps = (change.timestamp for change in @changes when change.removed)

          addedTimestamps.sort()
          removedTimestamps.sort()

          sum = (list) -> _.reduce list, ((memo, num) -> memo + num), 0

          averageAdded = sum(addedTimestamps) / addedTimestamps.length
          averageRemoved = sum(removedTimestamps) / removedTimestamps.length

          # Removing starts after 2000 ms, so there should be at least this difference between averages.
          @assertTrue averageAdded + 2000 < averageRemoved

          removedDelta = 0

          for removed, i in removedTimestamps when i < removedTimestamps.length - 1
            removedDelta += removedTimestamps[i + 1] - removed

          removedDelta /= removedTimestamps.length - 1

          # Each removed is approximately 91 ms apart. So the average of deltas should be somewhere there.
          @assertTrue removedDelta > 60, removedDelta
      ]

      testClientMultipleCursors: ->
        # Error is expected.
        @subscribe "multiple-cursors-1_#{idGeneration}",
          onError: @expect =>
            @assertTrue true

        # Error is expected.
        @subscribe "multiple-cursors-2_#{idGeneration}",
          onError: @expect =>
            @assertTrue true

      testClientLocalCollection: [
        ->
          Meteor.call "clearLocalCollection_#{idGeneration}", @expect (error) =>
            @assertFalse error, error
      ,
        ->
          Meteor.call "setLocalCollectionLimit_#{idGeneration}", 10, @expect (error) =>
            @assertFalse error, error
      ,
        ->
          @assertSubscribeSuccessful "localCollection_#{idGeneration}", @expect()
      ,
        ->
          @assertEqual LocalCollection.find({}).fetch(), []

          for i in [0...10]
            Meteor.call "insertLocalCollection_#{idGeneration}", {i: i}, @expect (error, documentId) =>
              @assertFalse error, error
              @assertTrue documentId
      ,
        ->
          # To wait a bit for change to propagate.
          Meteor.setTimeout @expect(), 100 # ms
      ,
        ->
          @assertEqual LocalCollection.find({}).count(), 10

          Meteor.call "setLocalCollectionLimit_#{idGeneration}", 5, @expect (error) =>
            @assertFalse error, error

          # To wait a bit for change to propagate.
          Meteor.setTimeout @expect(), 100 # ms
      ,
        ->
          @assertEqual LocalCollection.find({}).count(), 5

          for i in [0...10]
            Meteor.call "insertLocalCollection_#{idGeneration}", {i: i}, @expect (error, documentId) =>
              @assertFalse error, error
              @assertTrue documentId
      ,
        ->
          # To wait a bit for change to propagate.
          Meteor.setTimeout @expect(), 100 # ms
      ,
        ->
          @assertEqual LocalCollection.find({}).count(), 5

          Meteor.call "setLocalCollectionLimit_#{idGeneration}", 15, @expect (error) =>
            @assertFalse error, error

          # To wait a bit for change to propagate.
          Meteor.setTimeout @expect(), 100 # ms
      ,
        ->
          @assertEqual LocalCollection.find({}).count(), 15
      ]

      testClientUnblockedPublish: [
        @runOnServer ->
          @multiplexerCountBefore = 0
          for collection in allCollections when collection
            @multiplexerCountBefore += Object.keys(collection._driver.mongo._observeMultiplexers).length
      ,
        ->
          @userId = generateId()
          handle = @subscribe "unblocked-users-posts_#{idGeneration}", @userId
          handle?.stop()

          Meteor.setTimeout @expect(), 1000 # ms
      ,
        @runOnServer ->
          multiplexerCountAfter = 0
          for collection in allCollections when collection
            multiplexerCountAfter += Object.keys(collection._driver.mongo._observeMultiplexers).length

          @assertEqual @multiplexerCountBefore, multiplexerCountAfter
      ]

    # Register the test case.
    ClassyTestCase.addTest new ReactivePublishTestCase()
