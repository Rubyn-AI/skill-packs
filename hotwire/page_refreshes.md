---
name: turbo-page-refreshes
triggers:
  - page refresh
  - turbo refresh
  - broadcast refresh
  - request_turbo_stream_updates
gems:
  - turbo-rails
rails: ">=7.2"
---

# Turbo Page Refreshes (Turbo 8)

Page refreshes re-render the current page without a full navigation. Combined with morphing, they update only what changed while preserving client-side state.

## Pattern: Broadcast a page refresh

Instead of broadcasting individual stream actions, tell all subscribers to refresh the page. The server re-renders the full page and morphing diffs it.

```ruby
class Comment < ApplicationRecord
  belongs_to :post

  after_create_commit -> {
    broadcast_refresh_to post
  }
end
```

All users viewing the post's page will morph-refresh, seeing the new comment without losing scroll position or form state.

## When to use refresh vs targeted streams

| Scenario | Use |
|---------|-----|
| Adding one item to a list | `broadcast_append_to` (targeted) |
| Updating counts, stats, multiple sections | `broadcast_refresh_to` (full page morph) |
| Complex page with interdependent sections | `broadcast_refresh_to` |
| Simple chat-like append | `broadcast_append_to` |

Page refreshes are simpler to implement (no partial targeting) but transfer more data. Use targeted streams for high-frequency updates (chat) and refreshes for complex pages.

## Pattern: Debounced refreshes

Multiple rapid model changes coalesce into a single refresh.

```ruby
class Task < ApplicationRecord
  broadcasts_refreshes_to :project
  # Multiple task updates in quick succession = one page refresh
end
```

`broadcasts_refreshes_to` automatically debounces — if 5 tasks update within 500ms, subscribers get one refresh, not five.

## Enabling in the layout

```erb
<head>
  <meta name="turbo-refresh-method" content="morph">
  <meta name="turbo-refresh-scroll" content="preserve">
</head>
```

Both meta tags are required for smooth refresh behavior. Without `morph`, refreshes do a full body replacement (losing state). Without `preserve`, scroll jumps to the top.

## Anti-pattern: Using page refreshes for high-frequency updates

```ruby
# BAD — chat messages fire a full page refresh on every message
class Message < ApplicationRecord
  after_create_commit -> { broadcast_refresh_to conversation }
end
```

In a chat, messages arrive rapidly. Each refresh re-renders the entire page and morphs the DOM. For 10 messages/second, that's 10 full renders — sluggish and wasteful.

```ruby
# GOOD — append just the new message
class Message < ApplicationRecord
  after_create_commit -> {
    broadcast_append_to conversation,
      target: "messages",
      partial: "messages/message"
  }
end
```

Use targeted streams (`append`, `prepend`, `replace`) for individual item updates. Reserve page refreshes for complex multi-section pages where targeting every element is impractical.

## Anti-pattern: Forgetting morph-stable IDs

```erb
<%# BAD — no stable IDs, morphing can't match elements %>
<% @tasks.each do |task| %>
  <div class="task">
    <span><%= task.name %></span>
  </div>
<% end %>
```

Without `id` attributes, morphing treats every element as new. It replaces the entire list on every refresh, losing focus state, CSS transitions, and Stimulus controller state.

```erb
<%# GOOD — dom_id gives each element a stable identity %>
<% @tasks.each do |task| %>
  <div id="<%= dom_id(task) %>" class="task">
    <span><%= task.name %></span>
  </div>
<% end %>
```

Every element that morphing should track needs a unique, stable `id`. Use `dom_id(record)` for ActiveRecord objects.
