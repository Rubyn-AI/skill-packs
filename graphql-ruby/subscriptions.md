---
name: graphql-subscriptions
triggers:
  - graphql subscription
  - graphql websocket
  - graphql real-time
  - graphql live
  - graphql actioncable subscription
gems:
  - graphql
rails: ">=7.0"
---

# GraphQL-Ruby Subscriptions

Subscriptions push real-time updates to clients over WebSocket (typically ActionCable).

## Setup

```ruby
# app/graphql/my_app_schema.rb
class MyAppSchema < GraphQL::Schema
  use GraphQL::Subscriptions::ActionCableSubscriptions

  subscription Types::SubscriptionType
  mutation Types::MutationType
  query Types::QueryType
end
```

```ruby
# app/channels/graphql_channel.rb
class GraphqlChannel < ApplicationCable::Channel
  def subscribed
    @subscription_ids = []
  end

  def execute(data)
    result = MyAppSchema.execute(
      data["query"],
      context: { current_user: current_user, channel: self },
      variables: data["variables"],
      operation_name: data["operationName"]
    )

    payload = { result: result.to_h, more: result.subscription? }

    if result.subscription?
      @subscription_ids << result.context[:subscription_id]
    end

    transmit(payload)
  end

  def unsubscribed
    @subscription_ids.each do |sid|
      MyAppSchema.subscriptions.delete_subscription(sid)
    end
  end
end
```

## Pattern: Define a subscription type

```ruby
# app/graphql/types/subscription_type.rb
module Types
  class SubscriptionType < Types::BaseObject
    field :message_added, Types::MessageType, null: false do
      argument :room_id, ID, required: true
    end

    field :notification_received, Types::NotificationType, null: false

    def message_added(room_id:)
      # Return value is sent on initial subscription
      # Subsequent updates come from triggers
      object
    end
  end
end
```

## Pattern: Triggering subscription updates

```ruby
# In a model callback or service
class Message < ApplicationRecord
  after_create_commit :trigger_subscription

  private

  def trigger_subscription
    MyAppSchema.subscriptions.trigger(
      :message_added,
      { room_id: room_id },
      self  # The object sent to subscribers
    )
  end
end
```

## Pattern: Subscription with authorization

```ruby
class Types::SubscriptionType < Types::BaseObject
  field :message_added, Types::MessageType, null: false do
    argument :room_id, ID, required: true
  end

  def authorized?(room_id:)
    room = Room.find(room_id)
    room.members.include?(context[:current_user])
  end
end
```

## Anti-pattern: Triggering from the mutation resolver

```ruby
# BAD — tightly couples mutation to subscription
class Mutations::CreateMessage < Mutations::BaseMutation
  def resolve(body:, room_id:)
    message = Message.create!(body: body, room_id: room_id)
    MyAppSchema.subscriptions.trigger(:message_added, { room_id: room_id }, message)
    { message: message }
  end
end

# GOOD — trigger from model callback
# The subscription fires regardless of how the message was created
# (mutation, console, background job, API)
class Message < ApplicationRecord
  after_create_commit -> {
    MyAppSchema.subscriptions.trigger(:message_added, { room_id: room_id }, self)
  }
end
```
