---
name: turbo-broadcasting
triggers:
  - broadcast
  - broadcasts_to
  - broadcast_append
  - broadcast_replace
  - broadcast_remove
  - turbo_stream_from
  - action cable turbo
  - real-time update
  - live update
  - websocket turbo
gems:
  - turbo-rails
rails: ">=7.0"
---

# Turbo Broadcasting

Broadcasting pushes Turbo Stream updates to connected clients via ActionCable. Models declare what to broadcast; views subscribe with `turbo_stream_from`.

## Pattern: Model callbacks

```ruby
class Message < ApplicationRecord
  belongs_to :room

  # Shorthand — broadcasts all three lifecycle events
  broadcasts_to :room

  # Or explicitly control each:
  after_create_commit  -> { broadcast_append_to room }
  after_update_commit  -> { broadcast_replace_to room }
  after_destroy_commit -> { broadcast_remove_to room }
end
```

`broadcasts_to :room` is equivalent to all three explicit callbacks. It uses conventions: the partial is `messages/_message`, the target is `messages`.

## Pattern: Subscribing in the view

```erb
<%# Subscribe to broadcasts for this room %>
<%= turbo_stream_from @room %>

<div id="messages">
  <%= render @room.messages %>
</div>
```

`turbo_stream_from` generates a signed stream name and opens an ActionCable subscription. Multiple `turbo_stream_from` tags on one page work fine.

## Pattern: Custom partial and target

```ruby
after_create_commit -> {
  broadcast_append_to(
    room,
    target: "message_list",
    partial: "messages/compact_message",
    locals: { message: self, show_avatar: true }
  )
}
```

## Pattern: Broadcast later (async via ActiveJob)

For expensive partials, render asynchronously so the model callback doesn't block the request.

```ruby
after_create_commit -> {
  broadcast_append_later_to(room, target: "messages")
}
```

`_later` variants queue an ActiveJob that renders the partial and broadcasts. Requires a functioning job backend (Sidekiq, GoodJob, Solid Queue).

## Pattern: Broadcasting from anywhere (not just models)

```ruby
# From a service object or controller
Turbo::StreamsChannel.broadcast_append_to(
  "project_#{project.id}_activity",
  target: "activity_feed",
  partial: "activities/activity",
  locals: { activity: activity }
)

# Remove
Turbo::StreamsChannel.broadcast_remove_to(
  "project_#{project.id}_tasks",
  target: dom_id(task)
)

# Render arbitrary HTML
Turbo::StreamsChannel.broadcast_update_to(
  "dashboard",
  target: "stats",
  html: "<span>#{User.count} users</span>"
)
```

## Anti-pattern: Broadcasting in a transaction

Broadcasts sent inside a database transaction fire before the transaction commits. If the transaction rolls back, subscribers receive an update for a record that doesn't exist.

```ruby
# BAD — broadcast fires before commit
ActiveRecord::Base.transaction do
  @message = Message.create!(body: params[:body])
  broadcast_append_to(@room)  # Fires NOW, even if transaction fails
end

# GOOD — use after_create_commit (fires after commit)
class Message < ApplicationRecord
  after_create_commit -> { broadcast_append_to room }
end
```

## Anti-pattern: N+1 broadcasts

Creating 100 records triggers 100 broadcasts. Batch them.

```ruby
# BAD — 100 individual broadcasts
users.each { |u| Notification.create!(user: u, message: "Hello") }

# GOOD — bulk insert + single broadcast
Notification.insert_all(users.map { |u| { user_id: u.id, message: "Hello" } })
Turbo::StreamsChannel.broadcast_replace_to(
  "notifications",
  target: "notification_list",
  partial: "notifications/list",
  locals: { notifications: Notification.recent }
)
```

## Pattern: Multi-stream subscriptions

Subscribe to multiple streams on one page.

```erb
<%= turbo_stream_from @project %>
<%= turbo_stream_from @project, :tasks %>
<%= turbo_stream_from current_user, :notifications %>
```

The stream name is derived from the arguments: `@project` → `projects:42`, `[@project, :tasks]` → `projects:42:tasks`.

## Pattern: Authenticated streams

Turbo automatically signs stream names to prevent unauthorized subscriptions. But you should also verify at the channel level for extra security.

```ruby
# config/initializers/turbo.rb — already signed by default

# For custom authorization logic:
class ApplicationCable::Connection < ActionCable::Connection::Base
  identified_by :current_user

  def connect
    self.current_user = find_verified_user
  end

  private

  def find_verified_user
    User.find_by(id: cookies.encrypted[:user_id]) || reject_unauthorized_connection
  end
end
```

## ActionCable prerequisites

Broadcasting requires a running ActionCable server and a pub/sub adapter.

```yaml
# config/cable.yml
production:
  adapter: redis
  url: <%= ENV.fetch("REDIS_URL") %>

development:
  adapter: async  # In-memory, single process only

test:
  adapter: test
```

For production, use Redis or Solid Cable (Rails 8+). The `async` adapter is development-only and doesn't work across multiple processes/containers.
