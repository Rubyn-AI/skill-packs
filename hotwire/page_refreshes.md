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
